import MapKit
import SwiftUI
import ScooterCore

/// Un trajet de l'historique : son tracé et ses chiffres.
struct TripDetailView: View {
    let trip: TripRecord

    @State private var share = ShareState()

    var body: some View {
        let coordinates: [CLLocationCoordinate2D] = trip.route.map(\.mapCoordinate)
        return ScrollView {
            VStack(spacing: 14) {
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
                ShareMenu(summary: trip.summary, route: trip.route, title: trip.title, date: trip.startDate) { url in
                    share.receive(url)
                }
            }
        }
        .sharePresentation($share)
    }

    @ViewBuilder
    private func routeMap(_ coordinates: [CLLocationCoordinate2D]) -> some View {
        if coordinates.count > 1 {
            let segments: [RouteMap.Segment] = RouteMap.segments(route: trip.route, thrust: trip.thrust)
            let pins: [RouteMap.Pin] = RouteMap.pins(trip.highlights)
            Map(initialPosition: .automatic) {
                RouteMap.content(segments: segments, pins: pins)
                Marker("Départ", systemImage: "flag", coordinate: coordinates[0])
                    .tint(.green)
                Marker("Arrivée", systemImage: "stop.fill", coordinate: coordinates[coordinates.count - 1])
                    .tint(Theme.finish)
            }
            .frame(height: 340)
            .overlay(alignment: .bottom) {
                RouteMapLegend()
                    .padding(.bottom, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            Text("Tracé indisponible pour ce trajet.")
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
