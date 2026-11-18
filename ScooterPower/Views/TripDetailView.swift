import MapKit
import SwiftData
import SwiftUI
import ScooterCore

/// Un trajet de l'historique : son tracé et ses chiffres.
struct TripDetailView: View {
    let trip: TripRecord

    @Query(sort: \FriendTrip.receivedDate, order: .reverse) private var friendTrips: [FriendTrip]
    @State private var share = ShareState()
    @State private var showReplay = false
    @State private var showCreateSegment = false
    @State private var showRaceReplay = false

    var body: some View {
        let coordinates: [CLLocationCoordinate2D] = trip.route.map(\.mapCoordinate)
        return ScrollView {
            VStack(spacing: 14) {
                if let race = trip.race {
                    raceSummary(race)
                }
                if coordinates.count > 1 {
                    replayButton
                }
                if let race = ghostRace {
                    ghostButton(race)
                }
                if trip.recordedTimes != nil, trip.distanceMeters >= Segment.minimumLength {
                    Button {
                        showCreateSegment = true
                    } label: {
                        Label(L("Créer un segment"), systemImage: "flag.checkered")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.orange)
                }
                routeMap(coordinates)
                TripSegmentsSection(trip: trip)
                TripFigures(summary: trip.summary)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareMenu(
                    summary: trip.summary, route: trip.route, title: trip.title, date: trip.startDate,
                    sharedTrip: trip.shared(riderName: AppSettings.shared.riderName)
                ) { url in
                    share.receive(url)
                }
            }
        }
        .sharePresentation($share)
        .fullScreenCover(isPresented: $showRaceReplay) {
            if let race = trip.race {
                TripReplayView(
                    main: ReplayTrack(
                        id: "mine", name: trip.title,
                        replay: race.riderReplay(route: trip.route, points: trip.replayPoints),
                        color: SpeedometerView.neonRed),
                    riders: [ReplayTrack(id: "ghost", name: "👻 " + race.title, replay: race.ghostReplay(), color: .white)])
            }
        }
        .sheet(isPresented: $showCreateSegment) {
            CreateSegmentSheet(trip: trip)
        }
        .fullScreenCover(isPresented: $showReplay) {
            TripReplayView(
                main: ReplayTrack(id: "mine", name: trip.title, replay: trip.replay, color: SpeedometerView.neonRed),
                friends: friendTrips)
        }
    }

    /// Résultat de la course contre le ghost et bouton pour la revoir.
    private func raceSummary(_ race: GhostRaceResult) -> some View {
        let won: Bool? = race.won
        let color: Color = won == true ? RaceResultBanner.winColor : (won == false ? Theme.red : Theme.textSecondary)
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(verbatim: "👻").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: won == true ? "RACE WIN" : (won == false ? "RACE LOST" : L("Course non terminée")))
                        .font(.system(size: 24, weight: .black))
                        .italic()
                        .foregroundStyle(color)
                    Text(verbatim: race.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if let mine = race.riderTime, let ghost = race.ghostTime {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: Formatters.signed(ghost - mine, digits: 1) + " s")
                            .font(.system(size: 20, weight: .heavy).monospacedDigit())
                            .foregroundStyle(color)
                        Text(L("Vous \(Formatters.duration(mine)) · ghost \(Formatters.duration(ghost))"))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            Button {
                showRaceReplay = true
            } label: {
                Label(L("Revoir la course"), systemImage: "play.circle.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(.black)
                    .background(color == Theme.textSecondary ? Theme.cyan : color, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.7), lineWidth: 1.5))
    }

    /// Le trajet comme adversaire : `nil` s'il est trop court.
    private var ghostRace: GhostRace? {
        GhostRace.make(route: trip.route, points: trip.replayPoints, averageSpeedKmh: trip.averageSpeedKmh)
    }

    private func ghostButton(_ race: GhostRace) -> some View {
        Button {
            TripCommands.shared.raceGhost(race, title: L("Ghost du \(trip.title)"))
        } label: {
            HStack(spacing: 8) {
                Text(verbatim: "👻")
                Text(L("Faire la course contre ce trajet"))
            }
            .font(.system(size: 17, weight: .heavy))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(Theme.cyan)
            .background(Theme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.cyan.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var replayButton: some View {
        Button {
            showReplay = true
        } label: {
            Label(L("Revoir le trajet"), systemImage: "play.circle.fill")
                .font(.system(size: 18, weight: .heavy))
                .italic()
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(Color.white)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0xFF4A3D), Color(hex: 0xB01515)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: SpeedometerView.neonRed.opacity(0.6), radius: 10)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func routeMap(_ coordinates: [CLLocationCoordinate2D]) -> some View {
        if coordinates.count > 1 {
            let segments: [RouteMap.Segment] = RouteMap.segments(route: trip.route, thrust: trip.thrust)
            let pins: [RouteMap.Pin] = RouteMap.pins(trip.highlights)
            Map(initialPosition: .automatic) {
                RouteMap.content(segments: segments, pins: pins)
                Marker(L("Départ"), systemImage: "flag", coordinate: coordinates[0])
                    .tint(.green)
                Marker(L("Arrivée"), systemImage: "stop.fill", coordinate: coordinates[coordinates.count - 1])
                    .tint(Theme.finish)
            }
            .frame(height: 340)
            .overlay(alignment: .bottom) {
                RouteMapLegend()
                    .padding(.bottom, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            Text(L("Tracé indisponible pour ce trajet."))
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .cardStyle()
        }
    }
}

extension Coordinate {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
