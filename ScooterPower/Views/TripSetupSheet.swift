import SwiftData
import SwiftUI

/// Corriger la configuration du scooter d'un trajet déjà enregistré :
/// choisir une configuration existante ou en saisir une nouvelle.
struct TripSetupSheet: View {
    let trip: TripRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [TripRecord]
    @State private var newName = ""

    /// Configuration actuelle du trajet, nom nettoyé.
    private var current: String { AppSettings.cleaned(trip.setupName ?? "") }

    /// Toutes les configurations déjà utilisées, plus celle des réglages.
    private var names: [String] {
        var seen = Set<String>()
        var result: [String] = []
        let all: [String] = [AppSettings.shared.currentSetup] + trips.sorted { $0.startDate > $1.startDate }
            .map { AppSettings.cleaned($0.setupName ?? "") }
        for name in all where !seen.contains(name) {
            seen.insert(name)
            result.append(name)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(names, id: \.self) { name in
                        Button {
                            apply(name)
                        } label: {
                            HStack {
                                Text(verbatim: name)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if name == current {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.cyan)
                                }
                            }
                        }
                    }
                } header: {
                    Text(L("Configurations"))
                } footer: {
                    Text(L("Le trajet est rangé sous cette configuration dans les statistiques « Avant / après » et la comparaison avec d'autres pilotes."))
                }
                Section {
                    TextField(L("Nouvelle configuration"), text: $newName)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onSubmit { applyNew() }
                    Button(L("Utiliser ce nom")) { applyNew() }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(L("Configuration du trajet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Annuler")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private func applyNew() {
        let trimmed: String = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        apply(trimmed)
    }

    private func apply(_ name: String) {
        trip.setupName = AppSettings.cleaned(name)
        try? modelContext.save()
        dismiss()
    }
}

/// Ligne « Configuration : … » de la fiche d'un trajet, avec un bouton pour la changer.
struct TripSetupRow: View {
    let trip: TripRecord
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(Theme.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("Configuration"))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(verbatim: AppSettings.cleaned(trip.setupName ?? ""))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Text(L("Modifier"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.cyan)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
