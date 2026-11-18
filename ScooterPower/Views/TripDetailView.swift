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

    var body: some View {
        let coordinates: [CLLocationCoordinate2D] = trip.route.map(\.mapCoordinate)
        return ScrollView {
            VStack(spacing: 14) {
                if coordinates.count > 1 {
                    replayButton
                }
                routeMap(coordinates)
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
        .fullScreenCover(isPresented: $showReplay) {
            TripReplayView(
                main: ReplayTrack(id: "mine", name: trip.title, replay: trip.replay, color: SpeedometerView.neonRed),
                friends: friendTrips)
        }
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
