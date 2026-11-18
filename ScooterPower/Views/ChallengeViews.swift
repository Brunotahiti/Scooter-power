import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI
import UIKit
import ScooterCore

/// Section « Défi entre pilotes » de la page Statistiques : partager sa carte,
/// en ajouter une, et la liste des pilotes reçus.
struct ChallengeSection: View {
    let trips: [TripRecord]
    let setups: [String]

    @Query(sort: \RivalRecord.receivedDate, order: .reverse) private var rivals: [RivalRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var showMyCard = false
    @State private var pasteFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: L("Défi entre pilotes"))
            Text(L("Partagez votre carte de performances avec un autre pilote, ajoutez la sienne, et comparez-vous chiffre par chiffre."))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                actionButton(title: L("Ma carte"), icon: "qrcode", tint: Theme.orange) { showMyCard = true }
                actionButton(title: L("Coller une carte"), icon: "doc.on.clipboard", tint: Theme.cyan) { paste() }
            }
            if !rivals.isEmpty {
                rivalList
            }
        }
        .sheet(isPresented: $showMyCard) {
            MyCardSheet(trips: trips, setups: setups)
        }
        .alert(L("Aucune carte trouvée"), isPresented: $pasteFailed) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(L("Copiez d'abord le message ou le lien reçu de l'autre pilote, puis touchez « Coller une carte »."))
        }
    }

    private func actionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .foregroundStyle(Theme.textPrimary)
                .cardStyle(tint: tint)
        }
    }

    private var rivalList: some View {
        VStack(spacing: 0) {
            ForEach(rivals) { rival in
                NavigationLink {
                    RivalComparisonView(rival: rival, trips: trips, setups: setups)
                } label: {
                    rivalRow(rival)
                }
                if rival.id != rivals.last?.id {
                    Rectangle()
                        .fill(Theme.cardBorder)
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 12)
        .cardStyle()
    }

    private func rivalRow(_ rival: RivalRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: rival.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(verbatim: rival.setupName + " · " + AppDates.day(rival.cardDate))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .lineLimit(1)
            Spacer()
            Button(role: .destructive) {
                modelContext.delete(rival)
                try? modelContext.save()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L("Supprimer"))
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 8)
    }

    private func paste() {
        guard let text = UIPasteboard.general.string, let card = PerformanceCard(text: text) else {
            pasteFailed = true
            return
        }
        CardInbox.save(card, in: modelContext)
    }
}

/// Enregistre les cartes reçues, sans doublon.
@MainActor
enum CardInbox {
    static func save(_ card: PerformanceCard, in context: ModelContext) {
        let link: String = card.link.absoluteString
        let existing: [RivalRecord] = (try? context.fetch(FetchDescriptor<RivalRecord>())) ?? []
        // Une carte plus récente du même pilote et de la même configuration remplace l'ancienne.
        for old in existing where old.link == link
            || (old.riderName == card.riderName && old.setupName == card.setupName) {
            context.delete(old)
        }
        context.insert(RivalRecord(card: card))
        try? context.save()
    }
}

/// Reçoit les liens `scooterpower://card` ouverts depuis l'appareil photo ou un message.
struct CardReceiver: ViewModifier {
    @Binding var showStats: Bool
    @Binding var showGroupRide: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FriendTrip.receivedDate, order: .reverse) private var friendTrips: [FriendTrip]
    @State private var failed = false
    @State private var tripFailed = false
    @State private var receivedTrip: FriendTrip?

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                if url.isFileURL {
                    receiveTrip(url)
                    return
                }
                guard url.scheme?.lowercased() == PerformanceCard.scheme else { return }
                // QR code d'une balade de groupe : on la rejoint.
                if let ride = RideLink(url: url) {
                    GroupRideService.shared.join(ride)
                    showGroupRide = true
                    return
                }
                if let card = try? PerformanceCard(link: url) {
                    CardInbox.save(card, in: modelContext)
                    showStats = true
                } else {
                    failed = true
                }
            }
            .alert(L("Carte illisible"), isPresented: $failed) {
                Button(L("OK"), role: .cancel) {}
            } message: {
                Text(L("Ce lien ne contient pas de carte de performances valide. Demandez à l'autre pilote de vous la renvoyer."))
            }
            .alert(L("Trajet illisible"), isPresented: $tripFailed) {
                Button(L("OK"), role: .cancel) {}
            } message: {
                Text(L("Ce fichier ne contient pas de trajet valide, ou il vient d'une version plus récente de l'app."))
            }
            .fullScreenCover(item: $receivedTrip) { friend in
                if let shared = friend.shared {
                    TripReplayView(
                        main: ReplayTrack(
                            id: "friend", name: friend.displayName + " · " + friend.title,
                            replay: shared.replay, color: Theme.cyan),
                        friends: friendTrips.filter { $0.persistentModelID != friend.persistentModelID })
                }
            }
    }

    /// Fichier « .scooterpower » reçu d'un ami : il rejoint l'historique et se rejoue aussitôt.
    private func receiveTrip(_ url: URL) {
        guard url.pathExtension.lowercased() == SharedTrip.fileExtension else { return }
        let scoped: Bool = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let trip = try? SharedTrip(data: data) else {
            tripFailed = true
            return
        }
        // Le même trajet reçu deux fois n'est gardé qu'une fois.
        if let existing = friendTrips.first(where: { $0.fileData == data }) {
            receivedTrip = existing
            return
        }
        let friend = FriendTrip(trip: trip, data: data)
        modelContext.insert(friend)
        try? modelContext.save()
        receivedTrip = friend
    }
}

// MARK: - Ma carte

/// Ma carte de performances : QR code à scanner et lien à envoyer.
struct MyCardSheet: View {
    let trips: [TripRecord]
    let setups: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var setup = ""
    private let settings = AppSettings.shared

    private var card: PerformanceCard {
        var summaries: [TripSummary] = []
        for trip in trips where AppSettings.cleaned(trip.setupName ?? "") == setup {
            summaries.append(trip.summary)
        }
        return PerformanceCard(
            riderName: settings.riderName, setupName: setup, date: Date(),
            stats: PerformanceStats(trips: summaries))
    }

    private var message: String {
        L("Mes performances Scooter Power : \(card.link.absoluteString)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if setups.count > 1 {
                        Picker(L("Configuration"), selection: $setup) {
                            ForEach(setups, id: \.self) { name in
                                Text(verbatim: name).tag(name)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.orange)
                    }
                    if settings.riderName.isEmpty {
                        Text(L("Astuce : choisissez un pseudo dans les réglages pour que l'autre pilote vous reconnaisse."))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.orange)
                            .multilineTextAlignment(.center)
                    }
                    qrCode
                    Text(L("L'autre pilote scanne ce code avec l'appareil photo de son iPhone, ou ouvre le lien que vous lui envoyez."))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    ShareLink(item: message) {
                        Label(L("Envoyer ma carte"), systemImage: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(.black)
                            .background(Theme.cyan, in: Capsule())
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("Ma carte"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Fermer")) { dismiss() }
                }
            }
            .onAppear {
                if setup.isEmpty {
                    setup = setups.contains(settings.currentSetup) ? settings.currentSetup : (setups.last ?? settings.currentSetup)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var qrCode: some View {
        if let image = Self.qrImage(card.link.absoluteString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: 300)
                .accessibilityLabel(L("QR code de ma carte de performances"))
        }
    }

    static func qrImage(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled: CIImage = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Comparaison avec un autre pilote

/// Moi contre un autre pilote : l'écart en pourcentage est le mien par rapport au sien.
struct RivalComparisonView: View {
    let rival: RivalRecord
    let trips: [TripRecord]
    let setups: [String]

    /// Ma configuration comparée ; `nil` pour toutes.
    @State private var mySetup: String?
    @State private var didSetDefault = false

    private var myStats: PerformanceStats {
        var summaries: [TripSummary] = []
        for trip in trips where mySetup == nil || AppSettings.cleaned(trip.setupName ?? "") == mySetup {
            summaries.append(trip.summary)
        }
        return PerformanceStats(trips: summaries)
    }

    var body: some View {
        let rivalStats: PerformanceStats = rival.card?.stats ?? PerformanceStats(trips: [])
        let deltas: [StatDelta] = PerformanceComparison.deltas(baseline: rivalStats, modified: myStats, units: AppSettings.shared.units)
        var shown: [StatDelta] = []
        for delta in deltas where delta.baseline != nil || delta.modified != nil {
            shown.append(delta)
        }
        let wins: Int = shown.filter { $0.verdict == .better }.count
        let losses: Int = shown.filter { $0.verdict == .worse }.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(wins: wins, losses: losses)
                if setups.count > 1 {
                    setupPicker
                }
                VStack(spacing: 0) {
                    ForEach(shown.indices, id: \.self) { index in
                        StatsDeltaRow(delta: shown[index])
                        if index < shown.count - 1 {
                            Rectangle()
                                .fill(Theme.cardBorder)
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .cardStyle(tint: Theme.orange)
                Text(L("Chaque ligne : le chiffre de l'autre pilote, puis le vôtre. Le pourcentage est votre écart : vert quand vous faites mieux, rouge sinon."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(rival.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didSetDefault else { return }
            didSetDefault = true
            let current: String = AppSettings.shared.currentSetup
            mySetup = setups.contains(current) ? current : nil
        }
    }

    private func header(wins: Int, losses: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Moi"))
                    .font(.system(size: 13, weight: .heavy))
                    .italic()
                    .foregroundStyle(Theme.orange)
                Text(verbatim: String(wins))
                    .font(.system(size: 44, weight: .black))
                    .italic()
                    .foregroundStyle(Color(hex: 0x34D058))
            }
            Text(verbatim: "VS")
                .font(.system(size: 26, weight: .black))
                .italic()
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: rival.displayName)
                    .font(.system(size: 13, weight: .heavy))
                    .italic()
                    .foregroundStyle(Theme.cyan)
                    .lineLimit(1)
                Text(verbatim: String(losses))
                    .font(.system(size: 44, weight: .black))
                    .italic()
                    .foregroundStyle(Theme.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .cardStyle(tint: Theme.orange)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Chiffres gagnés : \(String(wins)). Chiffres perdus : \(String(losses))."))
    }

    private var setupPicker: some View {
        HStack {
            Text(L("Ma configuration"))
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Picker(L("Ma configuration"), selection: $mySetup) {
                Text(L("Toutes")).tag(String?.none)
                ForEach(setups, id: \.self) { name in
                    Text(verbatim: name).tag(String?.some(name))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.orange)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .cardStyle()
    }
}
