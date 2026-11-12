import MapKit
import SwiftUI
import ScooterCore

/// Carte du tracé en cours.
struct MapSheet: View {
    let route: [Coordinate]
    /// Faux en mode démo : le tracé synthétique n'est pas là où se trouve l'appareil.
    let showsUser: Bool

    @State private var position: MapCameraPosition

    init(route: [Coordinate], showsUser: Bool) {
        self.route = route
        self.showsUser = showsUser
        _position = State(initialValue: showsUser ? .userLocation(fallback: .automatic) : .automatic)
    }

    private var coordinates: [CLLocationCoordinate2D] {
        route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $position) {
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Theme.cyan, lineWidth: 5)
            }
            if let last = coordinates.last, !showsUser {
                Marker("Position", systemImage: "scooter", coordinate: last)
                    .tint(Theme.cyan)
            }
            if showsUser {
                UserAnnotation()
            }
        }
        .mapControls {
            if showsUser {
                MapUserLocationButton()
            }
            MapCompass()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
