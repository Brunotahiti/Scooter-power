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
        route.map(\.mapCoordinate)
    }

    var body: some View {
        Map(position: $position) {
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Theme.cyan, lineWidth: 5)
            }
            if !showsUser && !coordinates.isEmpty {
                Marker("Position", systemImage: "location.fill", coordinate: coordinates[coordinates.count - 1])
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
