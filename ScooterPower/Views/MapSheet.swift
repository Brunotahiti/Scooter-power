import MapKit
import SwiftUI
import ScooterCore

/// Carte d'un trajet : tracé coloré selon la poussée et repères des meilleures accélérations.
struct MapSheet: View {
    let route: [Coordinate]
    /// Poussée à chaque point du tracé, alignée sur `route`.
    let thrust: [Double]
    let highlights: [TripHighlight]
    /// Faux en mode démo, et pour un trajet terminé : la position actuelle n'a pas d'intérêt.
    let showsUser: Bool

    @State private var position: MapCameraPosition

    init(route: [Coordinate], thrust: [Double], highlights: [TripHighlight], showsUser: Bool) {
        self.route = route
        self.thrust = thrust
        self.highlights = highlights
        self.showsUser = showsUser
        _position = State(initialValue: showsUser ? .userLocation(fallback: .automatic) : .automatic)
    }

    var body: some View {
        let segments: [RouteMap.Segment] = RouteMap.segments(route: route, thrust: thrust)
        let pins: [RouteMap.Pin] = RouteMap.pins(highlights)
        return Map(position: $position) {
            RouteMap.content(segments: segments, pins: pins)
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
        .overlay(alignment: .bottom) {
            if !segments.isEmpty {
                RouteMapLegend()
                    .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
