import MapKit
import SwiftUI
import ScooterCore

/// Carte de la course contre le ghost, à la place des cartes de mesures :
/// le parcours du ghost, mon tracé en direct, le ghost et moi.
/// Avant le départ, elle montre tout le parcours ; en course, elle me suit.
struct GhostRaceMap: View {
    let model: TripViewModel
    @AppStorage(TripMapStyle.storageKey) private var satellite = true
    @State private var position: MapCameraPosition = .automatic

    private var racing: Bool { model.ghostStatus?.phase == .racing }
    private var me: Coordinate? { model.route.last }

    var body: some View {
        Map(position: $position, interactionModes: [.zoom]) {
            if model.ghostRoute.count > 1 {
                MapPolyline(coordinates: model.ghostRoute.map(\.mapCoordinate))
                    .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [10, 7]))
                if let start = model.ghostRoute.first {
                    Annotation(L("Départ"), coordinate: start.mapCoordinate) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14, weight: .bold))
                            .padding(6)
                            .background(Color.black.opacity(0.7), in: Circle())
                    }
                }
                if let end = model.ghostRoute.last {
                    Annotation(L("Arrivée"), coordinate: end.mapCoordinate) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.finish)
                            .padding(6)
                            .background(Color.black.opacity(0.7), in: Circle())
                    }
                }
            }
            if model.route.count > 1 {
                MapPolyline(coordinates: model.route.map(\.mapCoordinate))
                    .stroke(SpeedometerView.neonRed.opacity(0.9), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            if racing, let ghost = model.ghostStatus?.ghostCoordinate {
                // Le scooter (et non l'étiquette) sur la position.
                Annotation("", coordinate: ghost.mapCoordinate, anchor: UnitPoint(x: 0.5, y: 0.3)) {
                    RaceMarker(name: L("Ghost"), color: .white, heading: ghostHeading, ghost: true)
                }
            }
            if let me {
                Annotation("", coordinate: me.mapCoordinate, anchor: UnitPoint(x: 0.5, y: 0.7)) {
                    RaceMarker(name: L("Moi"), color: SpeedometerView.neonRed, heading: myHeading, ghost: false)
                }
            }
        }
        .mapStyle(TripMapStyle.style(satellite: satellite))
        .overlay(alignment: .topTrailing) {
            SatelliteToggle(satellite: $satellite)
                .padding(10)
        }
        .overlay(alignment: .bottomLeading) {
            legend.padding(10)
        }
        .overlay {
            if let status = model.ghostStatus, status.phase == .finished {
                RaceResultBanner(won: (status.gapSeconds ?? 0) >= 0, gap: status.gapSeconds ?? 0)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: model.ghostStatus?.phase == .finished)
        .frame(height: 430)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SpeedometerView.neonRed.opacity(0.7), lineWidth: 1.5))
        .onAppear { frameCamera(animated: false) }
        .onChange(of: model.route.count) { _, _ in frameCamera(animated: true) }
        .onChange(of: racing) { _, _ in frameCamera(animated: true) }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Capsule().fill(SpeedometerView.neonRed).frame(width: 18, height: 4)
                Text(L("Moi"))
            }
            HStack(spacing: 5) {
                Capsule().fill(Color.white).frame(width: 18, height: 4)
                Text(L("Ghost"))
            }
        }
        .font(.system(size: 12, weight: .bold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.7), in: Capsule())
    }

    /// En course : centrée sur moi, orientée dans le sens de la marche.
    /// Sinon : tout le parcours du ghost, et moi.
    private func frameCamera(animated: Bool) {
        let next: MapCameraPosition
        if racing, let me {
            next = .camera(MapCamera(centerCoordinate: me.mapCoordinate, distance: 650, heading: myHeading, pitch: 0))
        } else {
            var points: [Coordinate] = model.ghostRoute
            if let me { points.append(me) }
            guard let rect = Self.rect(points) else { return }
            next = .rect(rect)
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.9)) { position = next }
        } else {
            position = next
        }
    }

    private var myHeading: Double { Self.heading(model.route) }

    private var ghostHeading: Double {
        guard let ghost = model.ghostStatus?.ghostCoordinate else { return 0 }
        // Cap du parcours du ghost là où il se trouve.
        let route: [Coordinate] = model.ghostRoute
        guard let nearest = route.indices.min(by: {
            TripStatistics.haversine(route[$0], ghost) < TripStatistics.haversine(route[$1], ghost)
        }), nearest + 1 < route.count else { return 0 }
        return TripReplay.bearing(from: route[nearest], to: route[nearest + 1])
    }

    /// Cap depuis le dernier point assez éloigné, pour ne pas tourner sur place.
    static func heading(_ route: [Coordinate]) -> Double {
        guard let last = route.last else { return 0 }
        for previous in route.dropLast().reversed().prefix(20) where TripStatistics.haversine(previous, last) > 4 {
            return TripReplay.bearing(from: previous, to: last)
        }
        return 0
    }

    static func rect(_ points: [Coordinate]) -> MKMapRect? {
        guard !points.isEmpty else { return nil }
        var rect = MKMapRect.null
        for point in points {
            let p = MKMapPoint(point.mapCoordinate)
            rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        let padX: Double = max(rect.size.width * 0.15, 300)
        let padY: Double = max(rect.size.height * 0.15, 300)
        return rect.insetBy(dx: -padX, dy: -padY)
    }
}

/// Scooter vu du dessus avec son nom ; le ghost est blanc et translucide.
private struct RaceMarker: View {
    let name: String
    let color: Color
    let heading: Double
    let ghost: Bool

    var body: some View {
        VStack(spacing: 2) {
            if ghost { scooterView }
            tag
            if !ghost { scooterView }
        }
    }

    /// Étiquette au-dessus de moi, sous le ghost : les deux restent lisibles côte à côte.
    private var tag: some View {
        Text(verbatim: ghost ? "👻 " + name : name)
                .font(.system(size: 12, weight: .heavy))
                .italic()
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ghost ? Color.black.opacity(0.6) : color.opacity(0.85), in: Capsule())
                .overlay(Capsule().stroke(color, lineWidth: 1))
    }

    private var scooterView: some View {
        scooter
            .frame(width: 34, height: 34)
            .rotationEffect(.degrees(heading))
            .opacity(ghost ? 0.6 : 1)
            .shadow(color: color, radius: ghost ? 8 : 4)
    }

    @ViewBuilder
    private var scooter: some View {
        if let photo = UIImage(named: "ScooterTop") {
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
                .colorMultiply(ghost ? Color(white: 1.6) : .white)
        } else {
            Image(systemName: "location.north.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
        }
    }
}

/// « RACE WIN » ou « RACE LOST », en grand, à l'arrivée.
struct RaceResultBanner: View {
    let won: Bool
    /// Secondes d'avance (négatif : retard).
    let gap: Double

    static let winColor = Color(hex: 0x35D07F)

    var body: some View {
        let color: Color = won ? Self.winColor : Theme.red
        VStack(spacing: 4) {
            Image(systemName: won ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(won ? Theme.orange : .white)
            Text(verbatim: won ? "RACE WIN" : "RACE LOST")
                .font(.system(size: 44, weight: .black))
                .italic()
                .foregroundStyle(color)
                .shadow(color: color, radius: 12)
            Text(verbatim: Formatters.signed(gap, digits: 1) + " s")
                .font(.system(size: 22, weight: .heavy).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(color, lineWidth: 2))
    }
}
