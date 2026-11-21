import MapKit
import SwiftData
import SwiftUI
import ScooterCore

/// Les segments : portions de route chronométrées à chaque passage.
struct SegmentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SegmentRecord.createdAt, order: .reverse) private var segments: [SegmentRecord]
    @Query private var trips: [TripRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var nearby: [SharedSegmentService.Remote] = []
    @State private var searching = false
    @State private var searchFailed = false
    @State private var searched = false

    var body: some View {
        NavigationStack {
            List {
                communitySection
                if segments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L("Aucun segment"), systemImage: "flag.checkered")
                            .font(.headline)
                        Text(L("Ouvrez un trajet de l'historique, puis « Créer un segment » : choisissez une portion de route. Chaque fois que vous la reprendrez, elle sera chronométrée."))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 6)
                }
                ForEach(segments) { record in
                    NavigationLink {
                        SegmentDetailView(record: record)
                    } label: {
                        SegmentRow(record: record, efforts: record.efforts(in: trips))
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(segments[index]) }
                    try? modelContext.save()
                }
            }
            .navigationTitle(L("Segments"))
            .refreshable { await search() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Fermer")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SegmentRow: View {
    let record: SegmentRecord
    let efforts: [SegmentEffort]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.title3)
                .foregroundStyle(Theme.cyan)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: record.name).font(.headline)
                Text(verbatim: SegmentLength.text(record.lengthMeters) + " · "
                     + (efforts.count == 1 ? L("1 passage") : L("\(String(efforts.count)) passages")))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if let best = efforts.first {
                Text(verbatim: SegmentFormat.duration(best.duration))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.orange)
            }
        }
    }
}

@MainActor
enum SegmentLength {
    static func text(_ meters: Double) -> String {
        let units = AppSettings.shared.units
        return Formatters.decimal(units.distance(fromMeters: meters), digits: 2) + " " + units.distanceUnit
    }
}

extension SegmentsView {
    /// Segments partagés par les pilotes de la région, pas encore ajoutés.
    @ViewBuilder
    var communitySection: some View {
        let known: Set<String> = Set(segments.compactMap(\.remoteID))
        let fresh: [SharedSegmentService.Remote] = nearby.filter { !known.contains($0.id) }
        Section {
            if searching {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if searchFailed {
                Text(L("Recherche impossible. Vérifiez la connexion et la session iCloud."))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            } else if searched && fresh.isEmpty {
                Text(L("Aucun nouveau segment autour de vous. Créez-en un et partagez-le !"))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(fresh) { remote in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: remote.name).font(.headline)
                        Text(verbatim: SegmentLength.text(remote.lengthMeters) + " · " + L("par \(remote.creator)"))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button(L("Ajouter")) { add(remote) }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.cyan)
                }
            }
            Button {
                Task { await search() }
            } label: {
                Label(L("Chercher les segments autour de moi"), systemImage: "location.magnifyingglass")
            }
        } header: {
            Text(L("Communauté"))
        } footer: {
            Text(L("Les segments partagés par les pilotes de votre région, avec leur classement. Le meilleur temps porte la couronne de Roi de la route 👑."))
        }
    }

    func search() async {
        searching = true
        defer { searching = false; searched = true }
        do {
            nearby = try await SharedSegmentService.nearby(trips: trips)
            searchFailed = false
        } catch {
            searchFailed = true
        }
    }

    func add(_ remote: SharedSegmentService.Remote) {
        let record = SegmentRecord(name: remote.name, segment: Segment(path: remote.path))
        record.remoteID = remote.id
        record.creator = remote.creator
        modelContext.insert(record)
        try? modelContext.save()
    }
}

/// Un segment : sa carte et ses passages, du plus rapide au plus lent.
struct SegmentDetailView: View {
    @Bindable var record: SegmentRecord
    @Query private var trips: [TripRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var ranking: [SharedSegmentService.Ranked] = []
    @State private var loadingRanking = false
    @State private var publishing = false
    @State private var publishFailed = false
    @State private var askConsent = false
    private let settings = AppSettings.shared

    var body: some View {
        let efforts: [SegmentEffort] = record.efforts(in: trips)
        let path: [CLLocationCoordinate2D] = record.segment?.path.map(\.mapCoordinate) ?? []
        List {
            if path.count > 1 {
                Map(initialPosition: .automatic) {
                    MapPolyline(coordinates: path)
                        .stroke(Theme.orange, lineWidth: 5)
                    Marker(L("Départ"), systemImage: "flag", coordinate: path[0])
                        .tint(.green)
                    Marker(L("Arrivée"), systemImage: "flag.checkered", coordinate: path[path.count - 1])
                        .tint(Theme.finish)
                }
                .frame(height: 220)
                .listRowInsets(EdgeInsets())
            }
            Section {
                TextField(L("Nom"), text: $record.name)
                    .disabled(record.remoteID != nil)
                LabeledContent(L("Distance"), value: SegmentLength.text(record.lengthMeters))
                if let creator = record.creator, record.remoteID != nil {
                    LabeledContent(L("Créé par"), value: creator)
                }
            }
            communitySection
            Section {
                if efforts.isEmpty {
                    Text(L("Aucun passage pour l'instant."))
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(Array(efforts.enumerated()), id: \.element.id) { index, effort in
                    HStack {
                        Text(String(index + 1))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(index == 0 ? Theme.orange : Theme.textSecondary)
                            .frame(width: 28)
                        Text(effort.trip.startDate, format: .dateTime.day().month().year().hour().minute())
                        Spacer()
                        Text(verbatim: SegmentFormat.duration(effort.duration))
                            .font(.headline.monospacedDigit())
                    }
                }
            } header: {
                Text(L("Passages"))
            }
            if let best = efforts.first, let times = best.trip.recordedTimes,
               let race = Segment.ghost(route: best.trip.route, times: times, pass: best.pass) {
                Section {
                    Button {
                        TripCommands.shared.raceGhost(race, title: L("Ghost de \(record.name)"))
                    } label: {
                        Label(L("Faire la course contre mon meilleur passage"), systemImage: "flag.checkered")
                    }
                }
            }
        }
        .navigationTitle(record.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: record.remoteID) { await loadRanking() }
        .refreshable { await loadRanking() }
        .alert(L("Publier vos chronos ?"), isPresented: $askConsent) {
            Button(L("Publier")) {
                settings.setLeaderboardEnabled(true)
                Task { await publish() }
            }
            Button(L("Annuler"), role: .cancel) {}
        } message: {
            Text(L("Partager un segment publie aussi vos temps sur ce segment, avec votre prénom de pilote et le modèle de votre scooter. Vous pourrez désactiver les classements à tout moment."))
        }
        .alert(L("Partage impossible"), isPresented: $publishFailed) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(L("Vérifiez la connexion et la session iCloud, puis réessayez."))
        }
    }

    /// Partage ou classement de la communauté.
    @ViewBuilder
    private var communitySection: some View {
        if let remoteID = record.remoteID {
            Section {
                if loadingRanking && ranking.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if ranking.isEmpty {
                    Text(L("Aucun temps publié pour l'instant. Soyez le premier Roi de la route !"))
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(Array(ranking.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 10) {
                        Text(verbatim: index == 0 ? "👑" : String(index + 1))
                            .font(.headline.monospacedDigit())
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: row.rider)
                                .font(.body.weight(row.isMe ? .bold : .regular))
                                .foregroundStyle(row.isMe ? Theme.cyan : Theme.textPrimary)
                            if index == 0 {
                                Text(L("Roi de la route"))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Theme.orange)
                            } else if !row.model.isEmpty {
                                Text(verbatim: row.model)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        Text(verbatim: SegmentFormat.duration(row.seconds))
                            .font(.headline.monospacedDigit())
                    }
                }
                if !settings.leaderboardEnabled {
                    Button(L("Publier mes chronos sur ce segment"), systemImage: "trophy") { askConsent = true }
                }
            } header: {
                Text(L("Classement de la communauté"))
            }
            .id(remoteID)
        } else {
            Section {
                Button {
                    if settings.leaderboardEnabled {
                        Task { await publish() }
                    } else {
                        askConsent = true
                    }
                } label: {
                    if publishing {
                        ProgressView()
                    } else {
                        Label(L("Partager avec la communauté"), systemImage: "person.3.fill")
                    }
                }
                .disabled(publishing)
            } footer: {
                Text(L("Les pilotes de votre région pourront l'ajouter et se mesurer à votre temps. Le nom et le tracé ne pourront plus être modifiés."))
            }
        }
    }

    private func publish() async {
        if record.remoteID != nil {
            submitMine()
            return
        }
        publishing = true
        defer { publishing = false }
        do {
            try await SharedSegmentService.publish(record)
            try? modelContext.save()
            submitMine()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await loadRanking()
        } catch {
            publishFailed = true
        }
    }

    private func submitMine() {
        SharedSegmentService.submit(segments: [record], trips: trips, model: currentModel)
    }

    private var currentModel: String {
        let scooters: [Scooter] = (try? modelContext.fetch(FetchDescriptor<Scooter>())) ?? []
        return (scooters.first { $0.uid == settings.currentScooterID } ?? scooters.first)?.model ?? ""
    }

    private func loadRanking() async {
        guard let remoteID = record.remoteID else { return }
        loadingRanking = true
        defer { loadingRanking = false }
        ranking = (try? await SharedSegmentService.leaderboard(segmentID: remoteID, lengthMeters: record.lengthMeters)) ?? ranking
    }
}

/// Découpe d'un segment dans un trajet : deux curseurs pour le départ et l'arrivée.
struct CreateSegmentSheet: View {
    let trip: TripRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var start: Double = 0.2
    @State private var end: Double = 0.8
    @State private var name = ""

    private var segment: Segment? { Segment.cut(route: trip.route, from: start, to: end) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Map(initialPosition: .automatic) {
                        MapPolyline(coordinates: trip.route.map(\.mapCoordinate))
                            .stroke(Color.white.opacity(0.35), lineWidth: 4)
                        if let path = segment?.path.map(\.mapCoordinate), path.count > 1 {
                            MapPolyline(coordinates: path)
                                .stroke(Theme.orange, lineWidth: 6)
                            Marker(L("Départ"), systemImage: "flag", coordinate: path[0])
                                .tint(.green)
                            Marker(L("Arrivée"), systemImage: "flag.checkered", coordinate: path[path.count - 1])
                                .tint(Theme.finish)
                        }
                    }
                    .frame(height: 280)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    VStack(alignment: .leading) {
                        Text(L("Départ"))
                        Slider(value: $start, in: 0...1)
                            .tint(.green)
                            .onChange(of: start) { _, value in if value > end - 0.02 { end = min(1, value + 0.02) } }
                    }
                    VStack(alignment: .leading) {
                        Text(L("Arrivée"))
                        Slider(value: $end, in: 0...1)
                            .tint(Theme.finish)
                            .onChange(of: end) { _, value in if value < start + 0.02 { start = max(0, value - 0.02) } }
                    }
                    if let segment {
                        LabeledContent(L("Distance"), value: SegmentLength.text(segment.length))
                    } else {
                        Text(L("Segment trop court : allongez-le."))
                            .foregroundStyle(Theme.orange)
                    }
                    TextField(L("Nom du segment"), text: $name)
                } footer: {
                    Text(L("Choisissez une portion sans arrêt obligatoire. Le sens compte : le segment se parcourt du départ vers l'arrivée."))
                }
            }
            .navigationTitle(L("Créer un segment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Créer")) { save() }
                        .disabled(segment == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let segment else { return }
        let trimmed: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(SegmentRecord(name: trimmed.isEmpty ? L("Mon segment") : trimmed, segment: segment))
        try? modelContext.save()
        dismiss()
    }
}

/// Les segments parcourus pendant un trajet, dans sa fiche.
struct TripSegmentsSection: View {
    let trip: TripRecord
    @Query private var segments: [SegmentRecord]
    @Query private var trips: [TripRecord]

    var body: some View {
        let rows: [Row] = computeRows()
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(L("Segments"), systemImage: "flag.checkered")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.cyan)
                ForEach(rows) { row in
                    let rank: Int = row.rank
                    HStack {
                        Text(verbatim: row.record.name)
                        Spacer()
                        if rank == 1 {
                            Image(systemName: "trophy.fill").foregroundStyle(Theme.orange)
                        } else {
                            Text(verbatim: "#\(rank)").foregroundStyle(Theme.textSecondary)
                        }
                        Text(verbatim: SegmentFormat.duration(row.pass.duration))
                            .font(.headline.monospacedDigit())
                    }
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    struct Row: Identifiable {
        let record: SegmentRecord
        let pass: Segment.Pass
        let rank: Int
        var id: String { record.uid }
    }

    private func computeRows() -> [Row] {
        guard let times = trip.recordedTimes else { return [] }
        return segments.compactMap { record in
            guard let pass = record.segment?.bestPass(route: trip.route, times: times) else { return nil }
            let all: [SegmentEffort] = record.efforts(in: trips)
            let rank: Int = (all.firstIndex { $0.duration >= pass.duration } ?? all.count) + 1
            return Row(record: record, pass: pass, rank: rank)
        }
    }
}
