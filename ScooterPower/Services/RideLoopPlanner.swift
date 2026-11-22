import CoreLocation
import MapKit
import Observation
import ScooterCore

/// Propose des boucles sinueuses autour de la position actuelle : plusieurs
/// essais dans des directions différentes, itinéraires routiers réels (sans
/// autoroute), puis classement par virages, longueur et absence d'aller-retour.
@MainActor
@Observable
final class RideLoopPlanner {
    struct Candidate: Identifiable {
        let id = UUID()
        let route: [Coordinate]
        let meters: Double
        let seconds: TimeInterval
        let curviness: Double
        let score: Double
    }

    private(set) var candidates: [Candidate] = []
    private(set) var working = false
    private(set) var failed = false
    @ObservationIgnored private let locator = OneShotLocation()

    /// Vitesse moyenne prise pour une balade sur routes sinueuses (m/s, ≈ 35 km/h).
    static let cruise: Double = 9.7

    func generate(minutes: Int) async {
        working = true
        failed = false
        defer { working = false }
        guard let here = await locator.current() else {
            failed = true
            return
        }
        let start = Coordinate(latitude: here.latitude, longitude: here.longitude)
        let target: Double = Double(minutes) * 60 * Self.cruise
        let offset = Double.random(in: 0..<90)
        var found: [Candidate] = []
        for step in 0..<4 {
            let bearing: Double = offset + Double(step) * 90
            let stops: [Coordinate] = [start] + RideLoop.waypoints(start: start, meters: target, bearing: bearing) + [start]
            if let candidate = await route(through: stops, target: target) {
                found.append(candidate)
                candidates = found.sorted { $0.score > $1.score }
            }
        }
        if found.isEmpty { failed = true }
    }

    private func route(through stops: [Coordinate], target: Double) async -> Candidate? {
        var path: [Coordinate] = []
        var meters: Double = 0
        var seconds: TimeInterval = 0
        for index in 0..<(stops.count - 1) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: stops[index].mapCoordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: stops[index + 1].mapCoordinate))
            request.transportType = .automobile
            request.highwayPreference = .avoid
            request.tollPreference = .avoid
            guard let leg = try? await MKDirections(request: request).calculate().routes.first else { return nil }
            let polyline: MKPolyline = leg.polyline
            var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
            polyline.getCoordinates(&points, range: NSRange(location: 0, length: polyline.pointCount))
            path.append(contentsOf: points.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) })
            meters += leg.distance
            seconds += leg.expectedTravelTime
        }
        guard path.count > 2, meters >= 1000 else { return nil }
        return Candidate(route: path, meters: meters, seconds: seconds, curviness: RideLoop.curviness(path),
                         score: RideLoop.score(route: path, meters: meters, target: target))
    }

    /// La boucle comme ghost : il roule au temps estimé par Plans, réparti selon la distance.
    static func ghost(for candidate: Candidate) -> GhostRace? {
        var times: [TimeInterval] = [0]
        var travelled: Double = 0
        for index in 1..<candidate.route.count {
            travelled += TripStatistics.haversine(candidate.route[index - 1], candidate.route[index])
            times.append(candidate.meters > 0 ? travelled / candidate.meters * candidate.seconds : 0)
        }
        return GhostRace(route: candidate.route, times: times)
    }
}

/// Une seule position, pour choisir le départ de la balade.
@MainActor
final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func current() async -> CLLocationCoordinate2D? {
        if let recent = manager.location, recent.timestamp.timeIntervalSinceNow > -120 {
            return recent.coordinate
        }
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate: CLLocationCoordinate2D? = locations.last?.coordinate
        Task { @MainActor in self.finish(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    private func finish(_ coordinate: CLLocationCoordinate2D?) {
        continuation?.resume(returning: coordinate)
        continuation = nil
    }
}
