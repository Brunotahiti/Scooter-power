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

    /// Les deux scooters roulent côte à côte, chacun sur sa voie (en mètres).
    private static let laneOffset: Double = 4
    static let ghostBlue = Color(hex: 0x2EA8FF)
    /// Le parcours à suivre.
    static let routeYellow = Color(hex: 0xFFD60A)
    private static let red: Color = SpeedometerView.neonRed

    /// Orientation actuelle de la carte, pour tourner les scooters dans le bon sens.
    @State private var mapHeading: Double = 0

    var body: some View {
        let myTrail: [Coordinate] = RouteOffset.offset(model.route, meters: -Self.laneOffset)
        let ghostTrail: [Coordinate] = RouteOffset.offset(ghostTravelled, meters: Self.laneOffset)
        return Map(position: $position, interactionModes: [.zoom]) {
            if model.ghostRoute.count > 1 {
                // Le parcours à suivre, bien visible même sur la photo satellite :
                // bordure sombre, trait jaune en pointillés et flèches de direction.
                let path: [CLLocationCoordinate2D] = model.ghostRoute.map(\.mapCoordinate)
                MapPolyline(coordinates: path)
                    .stroke(Color.black.opacity(0.6), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: path)
                    .stroke(Self.routeYellow, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [14, 9]))
                ForEach(Array(arrows.enumerated()), id: \.offset) { _, arrow in
                    Annotation("", coordinate: arrow.coordinate.mapCoordinate) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.black)
                            .frame(width: 18, height: 18)
                            .background(Self.routeYellow, in: Circle())
                            .rotationEffect(.degrees(arrow.bearing - mapHeading))
                    }
                }
                if let start = model.ghostRoute.first {
                    Annotation(L("Départ"), coordinate: start.mapCoordinate) {
                        flag(color: .white)
                    }
                }
                if let end = model.ghostRoute.last {
                    Annotation(L("Arrivée"), coordinate: end.mapCoordinate) {
                        flag(color: Theme.finish)
                    }
                }
            }
            // Traînées lumineuses façon courses de motos néon : halo large et cœur clair.
            if ghostTrail.count > 1 {
                neonTrail(ghostTrail, color: Self.ghostBlue)
            }
            if myTrail.count > 1 {
                neonTrail(myTrail, color: Self.red)
            }
            if racing, let ghost = model.ghostStatus?.ghostCoordinate {
                let spot: Coordinate = RouteOffset.shift(ghost, bearing: ghostHeading, meters: Self.laneOffset)
                Annotation("", coordinate: spot.mapCoordinate) {
                    RaceBike(name: L("Ghost"), color: Self.ghostBlue, ghost: true,
                             frame: bikeFrame(at: spot, heading: ghostHeading), rotation: ghostHeading - mapHeading)
                }
            }
            if let me {
                let spot: Coordinate = racing
                    ? RouteOffset.shift(me, bearing: myHeading, meters: -Self.laneOffset) : me
                Annotation("", coordinate: spot.mapCoordinate) {
                    RaceBike(name: L("Moi"), color: Self.red, ghost: false,
                             frame: bikeFrame(at: spot, heading: myHeading), rotation: myHeading - mapHeading)
                }
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            mapHeading = context.camera.heading
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
                .stroke(Self.red.opacity(0.7), lineWidth: 1.5))
        .onAppear { frameCamera(animated: false) }
        .onChange(of: model.route.count) { _, _ in frameCamera(animated: true) }
        .onChange(of: racing) { _, _ in frameCamera(animated: true) }
    }

    @MapContentBuilder
    private func neonTrail(_ points: [Coordinate], color: Color) -> some MapContent {
        NeonTrail.content(points.map(\.mapCoordinate), color: color)
    }

    private func flag(color: Color) -> some View {
        Image(systemName: "flag.checkered")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(color)
            .padding(6)
            .background(Color.black.opacity(0.7), in: Circle())
    }

    /// Flèches de direction tous les 120 m le long du parcours.
    private var arrows: [(coordinate: Coordinate, bearing: Double)] {
        let route: [Coordinate] = model.ghostRoute
        guard route.count > 1 else { return [] }
        var result: [(coordinate: Coordinate, bearing: Double)] = []
        var travelled: Double = 0
        var next: Double = 60
        for index in 1..<route.count {
            let a: Coordinate = route[index - 1]
            let b: Coordinate = route[index]
            let step: Double = TripStatistics.haversine(a, b)
            while step > 0, travelled + step >= next {
                let ratio: Double = (next - travelled) / step
                let point = Coordinate(latitude: a.latitude + (b.latitude - a.latitude) * ratio,
                                       longitude: a.longitude + (b.longitude - a.longitude) * ratio)
                result.append((point, TripReplay.bearing(from: a, to: b)))
                next += 120
            }
            travelled += step
        }
        return result
    }

    /// Le parcours déjà fait par le ghost, jusqu'à sa position actuelle.
    private var ghostTravelled: [Coordinate] {
        guard racing || model.ghostStatus?.phase == .finished, let status = model.ghostStatus,
              let ghost = status.ghostCoordinate else { return [] }
        let route: [Coordinate] = model.ghostRoute
        guard route.count > 1 else { return [] }
        var total: Double = 0
        for index in 1..<route.count { total += TripStatistics.haversine(route[index - 1], route[index]) }
        let target: Double = status.ghostProgress * total
        var travelled: [Coordinate] = [route[0]]
        var done: Double = 0
        for index in 1..<route.count {
            done += TripStatistics.haversine(route[index - 1], route[index])
            if done >= target { break }
            travelled.append(route[index])
        }
        travelled.append(ghost)
        return travelled
    }

    private func bikeFrame(at coordinate: Coordinate, heading: Double) -> ReplayFrame {
        ReplayFrame(coordinate: coordinate, heading: heading, speedKmh: model.speedKmh ?? 0,
                    acceleration: 0, leanDegrees: 0, time: 0, index: 0)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Capsule().fill(Self.red).frame(width: 18, height: 4).shadow(color: Self.red, radius: 3)
                Text(L("Moi"))
            }
            HStack(spacing: 5) {
                Capsule().fill(Self.ghostBlue).frame(width: 18, height: 4).shadow(color: Self.ghostBlue, radius: 3)
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
            next = .camera(MapCamera(centerCoordinate: me.mapCoordinate, distance: 320, heading: myHeading, pitch: 0))
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

/// Scooter vu du dessus, dans le sens de la marche, avec son étiquette néon.
private struct RaceBike: View {
    let name: String
    let color: Color
    let ghost: Bool
    let frame: ReplayFrame
    /// Cap moins orientation de la carte.
    let rotation: Double

    var body: some View {
        ZStack {
            TopViewScooter(frame: frame, rotation: rotation, tint: color)
                .colorMultiply(ghost ? Color(hex: 0x9FD4FF) : Color(hex: 0xFFB3B3))
                .shadow(color: color, radius: 6)
                .shadow(color: color.opacity(0.8), radius: 12)
                .scaleEffect(0.7)
            Text(verbatim: ghost ? "👻 " + name : name)
                .font(.system(size: 11, weight: .heavy))
                .italic()
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(color.opacity(0.85), in: Capsule())
                .shadow(color: color, radius: 4)
                .offset(y: -40)
        }
        .frame(width: 90, height: 90)
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
