import SwiftData
import SwiftUI
import ScooterCore

/// Liste des trajets enregistrés, du plus récent au plus ancien, façon
/// tableau de bord néon : les trajets qui ont battu un record sont en rouge,
/// les autres en cyan.
struct HistoryView: View {
    @Query(sort: \TripRecord.startDate, order: .reverse) private var trips: [TripRecord]
    @Query(sort: \FriendTrip.receivedDate, order: .reverse) private var friendTrips: [FriendTrip]
    @State private var replayFriend: FriendTrip?
    @Query(sort: \GroupRideRecord.startDate, order: .reverse) private var groupRides: [GroupRideRecord]
    @State private var replayGroup: GroupRideRecord?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var path: [HistoryRoute] = []

    static let neonRed: Color = SpeedometerView.neonRed

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                HistoryHeader()
                tabs
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                content
                bottomBar
            }
            .background(backdrop.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HistoryRoute.self) { route in
                destination(route)
            }
            .fullScreenCover(item: $replayGroup) { ride in
                let tracks: [ReplayTrack] = ride.replayTracks
                if let first = tracks.first {
                    TripReplayView(main: first, friends: [], riders: Array(tracks.dropFirst()))
                }
            }
            .fullScreenCover(item: $replayFriend) { friend in
                if let shared = friend.shared {
                    TripReplayView(
                        main: ReplayTrack(
                            id: "friend", name: friend.displayName + " · " + friend.title,
                            replay: shared.replay, color: Theme.cyan),
                        friends: friendTrips.filter { $0.persistentModelID != friend.persistentModelID })
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func destination(_ route: HistoryRoute) -> some View {
        switch route {
        case .trip(let trip):
            TripDetailView(trip: trip)
        case .compare:
            TripComparisonView(trips: trips)
        case .records:
            RecordsView(trips: trips)
        case .stats:
            StatsView(trips: trips)
        }
    }

    private var backdrop: some View {
        ZStack {
            Color.black
            CarbonTexture()
                .opacity(0.18)
            RadialGradient(
                colors: [Self.neonRed.opacity(0.25), Color.clear],
                center: UnitPoint(x: 0.75, y: 0), startRadius: 10, endRadius: 320)
            RadialGradient(
                colors: [Self.neonRed.opacity(0.25), Color.clear],
                center: UnitPoint(x: 0.5, y: 1), startRadius: 10, endRadius: 300)
        }
    }

    // MARK: - Onglets

    private var tabs: some View {
        HStack(spacing: 8) {
            NeonTabButton(title: L("Comparer"), icon: "scalemass", isActive: false) {
                path.append(.compare)
            }
            // Il faut au moins deux trajets pour comparer.
            .disabled(trips.count < 2)
            .opacity(trips.count < 2 ? 0.45 : 1)
            NeonTabButton(title: L("Historique"), icon: "clock.arrow.circlepath", isActive: true) {}
                .allowsHitTesting(false)
            NeonTabButton(title: L("Fermer"), icon: "xmark", isActive: false) {
                dismiss()
            }
        }
        .frame(height: 46)
    }

    // MARK: - Liste

    @ViewBuilder
    private var content: some View {
        if trips.isEmpty && friendTrips.isEmpty && groupRides.isEmpty {
            ContentUnavailableView(
                L("Aucun trajet"),
                systemImage: "clock.arrow.circlepath",
                description: Text(L("Vos trajets terminés apparaîtront ici.")))
                .frame(maxHeight: .infinity)
        } else {
            let records: Set<PersistentIdentifier> = Self.recordTrips(trips)
            List {
                if !groupRides.isEmpty {
                    groupSection
                }
                if !friendTrips.isEmpty {
                    friendsSection
                }
                ForEach(trips) { trip in
                    Button {
                        path.append(.trip(trip))
                    } label: {
                        HistoryRow(trip: trip, isRecord: records.contains(trip.persistentModelID))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    /// Balades de groupe enregistrées : un toucher les rejoue avec tous les pilotes.
    private var groupSection: some View {
        Section {
            ForEach(groupRides) { ride in
                Button {
                    replayGroup = ride
                } label: {
                    GroupRideRow(ride: ride)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(groupRides[index]) }
            }
        } header: {
            Text(L("Balades de groupe"))
                .font(.system(size: 15, weight: .heavy))
                .italic()
                .foregroundStyle(HistoryView.neonRed)
        }
    }

    /// Trajets reçus d'amis : un toucher les rejoue sur la carte.
    private var friendsSection: some View {
        Section {
            ForEach(friendTrips) { friend in
                Button {
                    replayFriend = friend
                } label: {
                    FriendTripRow(friend: friend)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .swipeActions(edge: .leading) {
                    if let race = ghostRace(friend) {
                        Button {
                            raceGhost(race, friend: friend)
                        } label: {
                            Label(L("Course"), systemImage: "flag.checkered")
                        }
                        .tint(Theme.cyan)
                    }
                }
                .contextMenu {
                    if let race = ghostRace(friend) {
                        Button(L("Faire la course contre ce trajet"), systemImage: "flag.checkered") {
                            raceGhost(race, friend: friend)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(friendTrips[index]) }
            }
        } header: {
            Text(L("Trajets des amis"))
                .font(.system(size: 15, weight: .heavy))
                .italic()
                .foregroundStyle(Theme.cyan)
        } footer: {
            Text(L("Pour en recevoir, demandez à un ami d'ouvrir un trajet de son historique, puis Partager → Envoyer le trajet à un ami. Glissez un trajet vers la droite pour faire la course contre son ghost."))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    /// Le trajet d'un ami comme adversaire : `nil` s'il est trop court.
    private func ghostRace(_ friend: FriendTrip) -> GhostRace? {
        guard let shared = friend.shared else { return nil }
        return GhostRace.make(route: shared.route, points: shared.points, averageSpeedKmh: shared.averageSpeedKmh)
    }

    private func raceGhost(_ race: GhostRace, friend: FriendTrip) {
        TripCommands.shared.raceGhost(race, title: L("Ghost de \(friend.displayName)"))
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trips[index])
        }
    }

    /// Trajets qui, au moment où ils ont été faits, ont battu la vitesse
    /// maximale ou un temps d'accélération de tous les trajets précédents.
    /// Le tout premier trajet n'a rien à battre.
    static func recordTrips(_ trips: [TripRecord]) -> Set<PersistentIdentifier> {
        var result: Set<PersistentIdentifier> = []
        var bestSpeed: Double?
        var bestTimes: [SpeedInterval: TimeInterval] = [:]
        for trip in trips.sorted(by: { $0.startDate < $1.startDate }) {
            let speed: Double = trip.maxSpeedKmh.rounded()
            let times: [SpeedInterval: TimeInterval] = trip.summary.bestTimes
            var beaten = false
            if let previous = bestSpeed, speed > previous { beaten = true }
            for (interval, time) in times where time > 0 {
                let tenths: Double = (time * 10).rounded() / 10
                if let previous = bestTimes[interval] {
                    if tenths < previous { beaten = true }
                    bestTimes[interval] = min(previous, tenths)
                } else {
                    // Premier temps sur cet intervalle : record seulement s'il y avait déjà des trajets.
                    if bestSpeed != nil { beaten = true }
                    bestTimes[interval] = tenths
                }
            }
            if beaten { result.insert(trip.persistentModelID) }
            bestSpeed = max(bestSpeed ?? 0, speed)
        }
        return result
    }

    // MARK: - Bas de l'écran

    private var bottomBar: some View {
        HStack {
            RoundNeonButton(icon: "trophy.fill", label: L("Records")) {
                path.append(.records)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.black)
                    .overlay(Circle().stroke(Self.neonRed, lineWidth: 2))
                    .shadow(color: Self.neonRed.opacity(0.8), radius: 12)
                ScooterBadge()
                    .padding(10)
            }
            .frame(width: 92, height: 92)
            .accessibilityHidden(true)
            Spacer()
            RoundNeonButton(icon: "chart.bar.fill", label: L("Statistiques")) {
                path.append(.stats)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            LinearGradient(
                colors: [Color.clear, Self.neonRed.opacity(0.18)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea())
    }
}

enum HistoryRoute: Hashable {
    case trip(TripRecord)
    case compare
    case records
    case stats
}

// MARK: - En-tête

private struct HistoryHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    slashes
                    Text(L("Historique"))
                        .font(.system(size: 34, weight: .black))
                        .italic()
                        .foregroundStyle(Theme.textPrimary)
                        .shadow(color: HistoryView.neonRed.opacity(0.6), radius: 6)
                }
                Text(L("Trajets enregistrés"))
                    .font(.system(size: 15, weight: .medium))
                    .italic()
                    .foregroundStyle(Theme.textPrimary.opacity(0.8))
                    .padding(.leading, 46)
            }
            Spacer(minLength: 0)
            LiveScooter(speedFraction: 0.7, acceleration: 2, leanDegrees: 0, accent: HistoryView.neonRed)
                .frame(width: 70, height: 100)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, HistoryView.neonRed, Color.clear],
                        startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
                .shadow(color: HistoryView.neonRed, radius: 4)
        }
        .padding(.bottom, 10)
    }

    /// Trois barres obliques rouges devant le titre.
    private var slashes: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(HistoryView.neonRed.opacity(1 - 0.2 * Double(index)))
                    .frame(width: 7, height: 24)
                    .rotationEffect(.degrees(25))
            }
        }
        .shadow(color: HistoryView.neonRed, radius: 4)
        .frame(width: 38)
        .accessibilityHidden(true)
    }
}

// MARK: - Boutons

private struct NeonTabButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        let shape = HexagonFrame(tip: 12)
        let red: Color = HistoryView.neonRed
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                isActive
                    ? AnyShapeStyle(LinearGradient(
                        colors: [red.opacity(0.9), Color(hex: 0x7A0A0A)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color(hex: 0x15181C)),
                in: shape)
            .overlay(shape.stroke(isActive ? red : Color.white.opacity(0.25), lineWidth: 1.5))
            .shadow(color: isActive ? red.opacity(0.8) : Color.clear, radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct RoundNeonButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 62, height: 62)
                .background(
                    RadialGradient(
                        colors: [Color(hex: 0x2A2E33), Color(hex: 0x0B0D0F)],
                        center: .center, startRadius: 2, endRadius: 34),
                    in: Circle())
                .overlay(Circle().stroke(HistoryView.neonRed, lineWidth: 2))
                .shadow(color: HistoryView.neonRed.opacity(0.7), radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Ligne de trajet

private struct HistoryRow: View {
    let trip: TripRecord
    /// Vrai si ce trajet a battu un record : la carte est rouge.
    let isRecord: Bool

    private var color: Color { isRecord ? HistoryView.neonRed : Theme.cyan }

    private var units: UnitSystem { AppSettings.shared.units }

    private var distanceText: String {
        Formatters.decimal(units.distance(fromMeters: trip.distanceMeters), digits: 1) + " " + units.distanceUnit
    }

    private var speedValue: Double { units.speed(fromKmh: trip.maxSpeedKmh) }

    var body: some View {
        let shape = HexagonFrame(tip: 16)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .frame(width: 26)
                    Text(trip.title)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let won = trip.raceWon {
                        Text(verbatim: won ? "RACE WIN" : "RACE LOST")
                            .font(.system(size: 10, weight: .black))
                            .italic()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundStyle(.black)
                            .background(won ? RaceResultBanner.winColor : Theme.red, in: Capsule())
                            .fixedSize()
                    }
                }
                HStack(spacing: 10) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.cyan)
                        .frame(width: 26)
                    Text(verbatim: distanceText + "  |  " + Formatters.duration(trip.totalDuration))
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 4)
            MiniSpeedGauge(
                value: speedValue, maxValue: units.speedometerMax,
                unit: units.speedUnit, color: color)
                .frame(width: 76, height: 58)
            Image(systemName: "chevron.right")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isRecord ? HistoryView.neonRed : Theme.textPrimary)
        }
        .padding(.leading, 22)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Color(hex: 0x0B0E12)
                LinearGradient(
                    colors: [color.opacity(isRecord ? 0.35 : 0.18), Color.clear, color.opacity(0.12)],
                    startPoint: .leading, endPoint: .trailing)
            }
            .clipShape(shape))
        .overlay(shape.stroke(color, lineWidth: 1.8))
        .shadow(color: color.opacity(0.6), radius: 6)
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trip.title)
        .accessibilityValue(
            distanceText + ", " + Formatters.duration(trip.totalDuration) + ", "
                + L("\(Formatters.decimal(speedValue, digits: 0)) \(units.speedUnit) max")
                + (isRecord ? ", " + L("Record battu") : ""))
        .accessibilityAddTraits(.isButton)
    }
}

/// Petit compteur en demi-cercle : graduations, arc rempli jusqu'à la
/// vitesse maximale du trajet, valeur au centre.
private struct MiniSpeedGauge: View {
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color

    private var fraction: Double { min(1, max(0, value / max(1, maxValue))) }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.78)
                let radius: CGFloat = min(size.width / 2, size.height * 0.78) - 3
                let ticks = 14
                for index in 0...ticks {
                    let position: Double = Double(index) / Double(ticks)
                    let radians: Double = (180 - 180 * position) * Double.pi / 180
                    let outer: CGFloat = radius
                    let inner: CGFloat = radius - (index % 2 == 0 ? 7 : 4)
                    var tick = Path()
                    tick.move(to: CGPoint(x: center.x + outer * CGFloat(cos(radians)), y: center.y - outer * CGFloat(sin(radians))))
                    tick.addLine(to: CGPoint(x: center.x + inner * CGFloat(cos(radians)), y: center.y - inner * CGFloat(sin(radians))))
                    let lit: Bool = position <= fraction
                    context.stroke(
                        tick, with: .color(lit ? color : Color.white.opacity(0.25)),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
                var arc = Path()
                arc.addArc(
                    center: center, radius: radius + 2,
                    startAngle: .degrees(180), endAngle: .degrees(180 + 180 * fraction), clockwise: false)
                var glow = context
                glow.addFilter(.shadow(color: color, radius: 4))
                glow.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
            VStack(spacing: -2) {
                Text(verbatim: Formatters.decimal(value, digits: 0))
                    .font(.system(size: 22, weight: .black))
                    .italic()
                    .monospacedDigit()
                Text(L("\(unit) max"))
                    .font(.system(size: 11, weight: .medium))
                    .italic()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.textPrimary)
            .offset(y: 9)
        }
    }
}

/// Trajet d'un ami : pseudo, date, distance, durée et vitesse max, en cyan.
private struct FriendTripRow: View {
    let friend: FriendTrip

    private var units: UnitSystem { AppSettings.shared.units }

    var body: some View {
        let shape = HexagonFrame(tip: 16)
        let distance: String = Formatters.decimal(units.distance(fromMeters: friend.distanceMeters), digits: 1)
            + " " + units.distanceUnit
        let speed: String = Formatters.decimal(units.speed(fromKmh: friend.maxSpeedKmh), digits: 0)
        return HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.cyan)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: friend.displayName)
                    .font(.system(size: 18, weight: .bold))
                Text(verbatim: friend.title + "  |  " + distance + "  |  " + Formatters.duration(friend.totalDuration))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary.opacity(0.8))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            VStack(spacing: 0) {
                Text(verbatim: speed)
                    .font(.system(size: 22, weight: .black))
                    .italic()
                Text(L("\(units.speedUnit) max"))
                    .font(.system(size: 11, weight: .medium))
                    .italic()
            }
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.cyan)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
        .background(Color(hex: 0x0B0E12).clipShape(shape))
        .overlay(shape.stroke(Theme.cyan, lineWidth: 1.8))
        .shadow(color: Theme.cyan.opacity(0.5), radius: 6)
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(friend.displayName + ", " + friend.title)
        .accessibilityValue(distance + ", " + L("\(speed) \(units.speedUnit) max"))
        .accessibilityHint(L("Revoir le trajet"))
    }
}

/// Balade de groupe : date, pastilles de couleur et prénoms des pilotes.
private struct GroupRideRow: View {
    let ride: GroupRideRecord

    var body: some View {
        let shape = HexagonFrame(tip: 16)
        let tracks: [GroupRideTrack] = ride.tracks
        let names: String = ride.riderNames.joined(separator: ", ")
        return HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(HistoryView.neonRed)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: ride.title)
                    .font(.system(size: 17, weight: .bold))
                HStack(spacing: 5) {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { _, track in
                        Circle()
                            .fill(GroupRideView.color(track.colorIndex))
                            .frame(width: 9, height: 9)
                            .shadow(color: GroupRideView.color(track.colorIndex), radius: 3)
                    }
                    Text(verbatim: names)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(HistoryView.neonRed)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .padding(.vertical, 12)
        .background(Color(hex: 0x0B0E12).clipShape(shape))
        .overlay(shape.stroke(HistoryView.neonRed, lineWidth: 1.8))
        .shadow(color: HistoryView.neonRed.opacity(0.5), radius: 6)
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Balade de groupe") + ", " + ride.title)
        .accessibilityValue(names)
        .accessibilityHint(L("Revoir le trajet"))
    }
}
