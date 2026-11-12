import Foundation

/// Statistiques cumulées d'un trajet, à partir des points GPS.
public struct TripStatistics: Sendable {
    /// Précision horizontale maximale acceptée, en mètres.
    public static let maxAccuracy = 50.0
    /// Au-delà de cette vitesse implicite entre deux points, le point est rejeté (200 km/h).
    public static let maxImpliedSpeed = 200.0 / 3.6
    /// Vitesse au-dessus de laquelle le scooter est considéré en mouvement (3 km/h).
    public static let movingThreshold = 3.0 / 3.6
    /// Délai après lequel la dernière vitesse n'est plus affichée, en secondes.
    public static let speedStaleAfter = 5.0

    private enum Phase: Sendable { case idle, running, paused, stopped }

    private var phase = Phase.idle
    private var startTime: TimeInterval = 0
    private var pausedTotal: TimeInterval = 0
    private var pauseStart: TimeInterval = 0
    private var stopTime: TimeInterval = 0

    /// Dernier point accepté, servant d'origine au segment suivant. Effacé à la reprise.
    private var anchor: LocationSample?
    /// Horodatage du dernier point accepté, jamais effacé : garantit l'ordre.
    private var lastTimestamp: TimeInterval?
    private var lastSpeed: Double?

    public private(set) var maxSpeedKmh: Double = 0
    public private(set) var distanceMeters: Double = 0
    public private(set) var movingDuration: TimeInterval = 0
    public private(set) var altitudeMeters: Double?
    public private(set) var route: [Coordinate] = []

    public init() {}

    public var averageSpeedKmh: Double {
        movingDuration > 0 ? distanceMeters / movingDuration * 3.6 : 0
    }

    public mutating func start(at time: TimeInterval) {
        guard phase == .idle else { return }
        phase = .running
        startTime = time
    }

    public mutating func pause(at time: TimeInterval) {
        guard phase == .running else { return }
        phase = .paused
        pauseStart = time
    }

    public mutating func resume(at time: TimeInterval) {
        guard phase == .paused else { return }
        phase = .running
        pausedTotal += max(0, time - pauseStart)
        anchor = nil
    }

    public mutating func stop(at time: TimeInterval) {
        switch phase {
        case .running:
            stopTime = time
        case .paused:
            stopTime = pauseStart
        case .idle, .stopped:
            return
        }
        phase = .stopped
    }

    public mutating func add(_ sample: LocationSample) {
        guard phase == .running, Self.isValid(sample) else { return }
        // Un point antérieur au départ est un point en cache : il ne fait pas partie du trajet.
        guard sample.timestamp >= startTime else { return }
        if let lastTimestamp, sample.timestamp <= lastTimestamp { return }

        if let anchor {
            let dt = sample.timestamp - anchor.timestamp
            let distance = Self.haversine(
                Coordinate(latitude: anchor.latitude, longitude: anchor.longitude),
                Coordinate(latitude: sample.latitude, longitude: sample.longitude))
            guard dt > 0, distance / dt <= Self.maxImpliedSpeed else { return }
            distanceMeters += distance
            if sample.speed > Self.movingThreshold {
                movingDuration += dt
            }
        }

        anchor = sample
        lastTimestamp = sample.timestamp
        lastSpeed = sample.speed
        maxSpeedKmh = max(maxSpeedKmh, sample.speed * 3.6)
        altitudeMeters = sample.altitude
        route.append(Coordinate(latitude: sample.latitude, longitude: sample.longitude))
    }

    /// Dernière vitesse valide, ou `nil` s'il n'y a pas eu de point valide récemment.
    public func currentSpeedKmh(at now: TimeInterval) -> Double? {
        guard let lastTimestamp, let lastSpeed, now - lastTimestamp <= Self.speedStaleAfter else { return nil }
        return lastSpeed * 3.6
    }

    /// Temps écoulé depuis le départ, pauses exclues.
    public func totalDuration(at now: TimeInterval) -> TimeInterval {
        let end: TimeInterval
        switch phase {
        case .idle: return 0
        case .running: end = now
        case .paused: end = pauseStart
        case .stopped: end = stopTime
        }
        return max(0, end - startTime - pausedTotal)
    }

    private static func isValid(_ s: LocationSample) -> Bool {
        s.timestamp.isFinite && s.latitude.isFinite && s.longitude.isFinite
            && s.speed.isFinite && s.altitude.isFinite && s.horizontalAccuracy.isFinite
            && s.speed >= 0 && s.horizontalAccuracy >= 0 && s.horizontalAccuracy <= maxAccuracy
    }

    /// Distance orthodromique en mètres.
    public static func haversine(_ a: Coordinate, _ b: Coordinate) -> Double {
        let radius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, h.squareRoot()))
    }
}
