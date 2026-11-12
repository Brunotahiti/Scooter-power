import MapKit
import SwiftUI
import ScooterCore

/// Un trajet de l'historique : son tracé et ses chiffres.
struct TripDetailView: View {
    let trip: TripRecord

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
                ShareMenu(summary: trip.summary, route: trip.route, title: trip.title, date: trip.startDate)
            }
        }
    }

    @ViewBuilder
    private func routeMap(_ coordinates: [CLLocationCoordinate2D]) -> some View {
        if coordinates.count > 1 {
            Map(initialPosition: .automatic) {
                MapPolyline(coordinates: coordinates)
                    .stroke(Theme.cyan, lineWidth: 5)
                Marker("Départ", systemImage: "flag", coordinate: coordinates[0])
                    .tint(.green)
                Marker("Arrivée", systemImage: "flag.checkered", coordinate: coordinates[coordinates.count - 1])
                    .tint(Theme.finish)
            }
            .frame(height: 300)
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
