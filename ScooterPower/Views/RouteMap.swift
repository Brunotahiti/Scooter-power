import MapKit
import SwiftUI
import ScooterCore

/// Contenu de carte commun : le tracé coloré selon la poussée et les repères
/// des meilleures accélérations du trajet.
enum RouteMap {
    struct Segment: Identifiable {
        let id: Int
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    struct Pin: Identifiable {
        let id: Int
        let title: String
        let icon: String
        let tint: Color
        let coordinate: CLLocationCoordinate2D
    }

    static let brakingColor = Color(hex: 0x9B7BFF)

    /// Couleur d'un point du tracé selon la poussée à cet instant.
    static func color(for thrust: Double) -> Color {
        switch AccelerationAnalyzer.level(for: thrust) {
        case .stable: return Theme.cyan
        case .accelerating: return Theme.orange
        case .acceleratingHard: return Theme.red
        case .braking, .brakingHard: return brakingColor
        }
    }

    /// Découpe le tracé en morceaux de même couleur. Sans poussée alignée, un seul morceau cyan.
    static func segments(route: [Coordinate], thrust: [Double]) -> [Segment] {
        let points: [CLLocationCoordinate2D] = route.map(\.mapCoordinate)
        guard points.count > 1 else { return [] }
        guard thrust.count == points.count else {
            return [Segment(id: 0, coordinates: points, color: Theme.cyan)]
        }
        var result: [Segment] = []
        var current: [CLLocationCoordinate2D] = [points[0]]
        var currentColor: Color = color(for: thrust[1])
        for index in 1..<points.count {
            let pointColor: Color = color(for: thrust[index])
            if pointColor != currentColor, current.count > 1 {
                result.append(Segment(id: result.count, coordinates: current, color: currentColor))
                // Le nouveau morceau repart du dernier point, pour que le tracé reste continu.
                current = [current[current.count - 1]]
                currentColor = pointColor
            }
            current.append(points[index])
        }
        if current.count > 1 {
            result.append(Segment(id: result.count, coordinates: current, color: currentColor))
        }
        return result
    }

    static func pins(_ highlights: [TripHighlight]) -> [Pin] {
        var result: [Pin] = []
        for highlight in highlights {
            let coordinate: CLLocationCoordinate2D = highlight.end.mapCoordinate
            switch highlight.kind {
            case .sprint(let interval):
                let time: String = Formatters.decimal(highlight.value, digits: 1) + " s"
                result.append(Pin(
                    id: result.count, title: interval.label + " · " + time,
                    icon: "flag.checkered", tint: Theme.orange, coordinate: coordinate))
            case .peakAcceleration:
                let value: String = Formatters.signed(highlight.value, digits: 1) + " m/s²"
                result.append(Pin(
                    id: result.count, title: L("Pic") + " " + value,
                    icon: "bolt.fill", tint: Theme.red, coordinate: coordinate))
            }
        }
        return result
    }

    @MapContentBuilder
    static func content(segments: [Segment], pins: [Pin]) -> some MapContent {
        ForEach(segments) { segment in
            MapPolyline(coordinates: segment.coordinates)
                .stroke(segment.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        ForEach(pins) { pin in
            Marker(pin.title, systemImage: pin.icon, coordinate: pin.coordinate)
                .tint(pin.tint)
        }
    }
}

/// Légende des couleurs du tracé.
struct RouteMapLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            item(Theme.cyan, L("Stable"))
            item(Theme.orange, L("Accélération"))
            item(Theme.red, L("Accélération forte"))
            item(RouteMap.brakingColor, L("Freinage"))
        }
        .font(.system(size: 11, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.7), in: Capsule())
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Capsule()
                .fill(color)
                .frame(width: 14, height: 5)
            Text(text)
        }
    }
}
