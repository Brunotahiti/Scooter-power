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
    /// Course contre le ghost : son parcours et sa position actuelle.
    var ghostRoute: [Coordinate] = []
    var ghost: Coordinate?

    @State private var position: MapCameraPosition

    init(route: [Coordinate], thrust: [Double], highlights: [TripHighlight], showsUser: Bool,
         ghostRoute: [Coordinate] = [], ghost: Coordinate? = nil) {
        self.route = route
        self.thrust = thrust
        self.highlights = highlights
        self.showsUser = showsUser
        self.ghostRoute = ghostRoute
        self.ghost = ghost
        _position = State(initialValue: showsUser ? .userLocation(fallback: .automatic) : .automatic)
    }

    var body: some View {
        let segments: [RouteMap.Segment] = RouteMap.segments(route: route, thrust: thrust)
        let pins: [RouteMap.Pin] = RouteMap.pins(highlights)
        return Map(position: $position) {
            if ghostRoute.count > 1 {
                MapPolyline(coordinates: ghostRoute.map(\.mapCoordinate))
                    .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 6]))
            }
            RouteMap.content(segments: segments, pins: pins)
            if ghost == nil, ghostRoute.count > 1, let start = ghostRoute.first {
                Marker(L("Départ du ghost"), systemImage: "flag.checkered", coordinate: start.mapCoordinate)
                    .tint(.white)
            }
            if let ghost {
                Annotation(L("Ghost"), coordinate: ghost.mapCoordinate) {
                    Text(verbatim: "👻")
                        .font(.system(size: 26))
                        .padding(4)
                        .background(Color.black.opacity(0.55), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
                }
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
