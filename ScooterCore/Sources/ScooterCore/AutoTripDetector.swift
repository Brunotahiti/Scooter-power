import Foundation

/// Démarrage et arrêt automatiques des trajets à partir de la vitesse GPS.
/// - Départ : au moins `startSpeedKmh` pendant `startSeconds` (mesures
///   espacées de moins de `maxGap` secondes) ;
/// - Arrivée : sous `stopSpeedKmh` pendant `stopSeconds` d'affilée.
public struct AutoTripDetector: Sendable {
    public struct Configuration: Sendable {
        public var startSpeedKmh: Double = 15
        public var startSeconds: TimeInterval = 15
        public var stopSpeedKmh: Double = 4
        public var stopSeconds: TimeInterval = 180
        public var maxGap: TimeInterval = 6
        public init() {}
    }

    public let configuration: Configuration
    private var movingSince: TimeInterval?
    private var stoppedSince: TimeInterval?
    private var lastTime: TimeInterval?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public mutating func reset() {
        movingSince = nil
        stoppedSince = nil
        lastTime = nil
    }

    /// À l'arrêt (pas de trajet) : vrai quand le départ est détecté.
    public mutating func idleSample(time: TimeInterval, kmh: Double) -> Bool {
        defer { lastTime = time }
        guard kmh.isFinite, kmh >= 0 else { return false }
        if let lastTime, time - lastTime > configuration.maxGap { movingSince = nil }
        guard kmh >= configuration.startSpeedKmh else {
            movingSince = nil
            return false
        }
        let since: TimeInterval = movingSince ?? time
        movingSince = since
        if time - since >= configuration.startSeconds {
            movingSince = nil
            return true
        }
        return false
    }

    /// Pendant un trajet : vrai quand l'arrivée est détectée.
    public mutating func ridingSample(time: TimeInterval, kmh: Double) -> Bool {
        guard kmh.isFinite else { return false }
        guard kmh >= 0, kmh < configuration.stopSpeedKmh else {
            stoppedSince = nil
            return false
        }
        let since: TimeInterval = stoppedSince ?? time
        stoppedSince = since
        if time - since >= configuration.stopSeconds {
            stoppedSince = nil
            return true
        }
        return false
    }
}
