import SwiftData
import SwiftUI
import ScooterCore

/// Classements en ligne : les meilleurs chronos des pilotes du même modèle de scooter.
struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Scooter.createdAt) private var scooters: [Scooter]
    @Query private var trips: [TripRecord]
    @State private var interval: SpeedInterval = SpeedInterval.flagship(for: AppSettings.shared.units)
    @State private var sameModel = true
    @State private var rows: [LeaderboardRow] = []
    @State private var loading = false
    @State private var failed = false
    private let settings = AppSettings.shared

    private var scooter: Scooter? {
        scooters.first { $0.uid == settings.currentScooterID } ?? scooters.first
    }

    private var modelKey: String? {
        scooter.map { Leaderboard.modelKey($0.model) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    private var enabled: Binding<Bool> {
        Binding(get: { settings.leaderboardEnabled }, set: { value in
            settings.setLeaderboardEnabled(value)
            if value {
                publishExisting()
            } else {
                Task { await LeaderboardService.removeMine() }
            }
            reload()
        })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(L("Publier mes chronos"), isOn: enabled)
                        .tint(Theme.cyan)
                } footer: {
                    Text(L("Seuls votre prénom de pilote, le modèle de votre scooter et vos chronos sont publiés. Désactivez pour les retirer."))
                }

                if modelKey == nil {
                    Section {
                        Label(L("Indiquez la marque et le modèle de votre scooter dans le Garage pour vous mesurer aux pilotes du même modèle."),
                              systemImage: "scooter")
                            .font(.footnote)
                    }
                }

                Section {
                    Picker(L("Chrono"), selection: $interval) {
                        ForEach(SpeedInterval.shown(for: settings.units), id: \.self) { item in
                            Text(item.fullLabel).tag(item)
                        }
                    }
                    if modelKey != nil {
                        Picker(L("Classement"), selection: $sameModel) {
                            Text(scooter?.model ?? "").tag(true)
                            Text(L("Tous les scooters")).tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section {
                    if loading && rows.isEmpty {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if failed {
                        Text(L("Classement indisponible. Vérifiez la connexion et la session iCloud."))
                            .foregroundStyle(Theme.textSecondary)
                    } else if rows.isEmpty {
                        Text(L("Aucun chrono pour l'instant. Soyez le premier !"))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            rowView(rank: index + 1, row: row)
                        }
                    }
                }
            }
            .navigationTitle(L("Classements"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Fermer")) { dismiss() }
                }
            }
            .refreshable { await load() }
            .task(id: "\(Leaderboard.intervalID(interval))-\(sameModel)") { await load() }
        }
        .preferredColorScheme(.dark)
    }

    private func rowView(rank: Int, row: LeaderboardRow) -> some View {
        HStack(spacing: 12) {
            Text(String(rank))
                .font(.headline.monospacedDigit())
                .foregroundStyle(rank <= 3 ? Theme.orange : Theme.textSecondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.rider)
                    .font(.body.weight(row.isMe ? .bold : .regular))
                    .foregroundStyle(row.isMe ? Theme.cyan : Theme.textPrimary)
                if !sameModel || modelKey == nil {
                    Text(row.model)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            Text(Formatters.decimal(row.seconds, digits: 2) + " s")
                .font(.headline.monospacedDigit())
        }
    }

    private func reload() {
        Task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            rows = try await LeaderboardService.top(interval: interval, modelKey: sameModel ? modelKey : nil)
            failed = false
        } catch {
            failed = true
        }
    }

    /// À l'activation : publie les meilleurs temps déjà enregistrés avec ce scooter.
    private func publishExisting() {
        guard let scooter else { return }
        let mine: [TripRecord] = trips.filter { $0.scooterID == scooter.uid || $0.scooterID == nil }
        LeaderboardService.submit(trips: mine, scooter: scooter)
    }
}
