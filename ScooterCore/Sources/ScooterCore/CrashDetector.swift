import Foundation

/// Détecte une chute probable pendant un trajet, à partir des capteurs du
/// téléphone fixé au guidon et de la vitesse GPS.
///
/// Deux scénarios déclenchent l'alerte, toujours peu après avoir roulé :
/// - **scooter couché** : le téléphone reste incliné de plus de `tiltDegrees`
///   par rapport à sa position de référence pendant `tiltDuration` secondes
///   (aucun scooter ne roule penché à plus de 60°) ;
/// - **choc puis arrêt** : une accélération d'au moins `impactG`, suivie d'un
///   arrêt complet dans les secondes qui suivent.
///
/// Un nid-de-poule (choc sans arrêt), la béquille ou un scooter garé (penché
/// sans avoir roulé juste avant) ne déclenchent rien.
public struct CrashDetector: Sendable {
    public struct Configuration: Sendable {
        /// Choc minimal, en g (accélération propre, gravité retirée).
        public var impactG: Double = 4.0
        /// Inclinaison minimale du téléphone par rapport à sa position de référence.
        public var tiltDegrees: Double = 60
        /// Durée pendant laquelle l'inclinaison doit persister (s).
        public var tiltDuration: TimeInterval = 2.5
        /// Vitesse au-dessus de laquelle on « roulait » (km/h).
        public var ridingSpeedKmh: Double = 15
        /// Une chute n'est cherchée que si l'on roulait il y a moins de ce délai (s).
        public var ridingWindow: TimeInterval = 12
        /// Vitesse sous laquelle on est arrêté (km/h).
        public var stoppedSpeedKmh: Double = 4
        /// Après un choc, délai pendant lequel on attend l'arrêt (s).
        public var stopWindow: TimeInterval = 8
        /// Durée minimale entre deux alertes (s).
        public var cooldown: TimeInterval = 90

        public init() {}
    }

    /// Ce qui a déclenché la dernière alerte, pour le journal de réglage.
    public struct Trigger: Sendable, Equatable, Codable {
        public enum Reason: String, Sendable, Codable {
            case laidDown, impactThenStop
        }
        public var reason: Reason
        /// Plus fort choc des dernières secondes, en g.
        public var peakG: Double
        /// Inclinaison du téléphone au déclenchement, en degrés.
        public var tiltDegrees: Double
        /// Vitesse la plus haute des secondes précédentes, en km/h.
        public var speedBeforeKmh: Double
    }

    public let configuration: Configuration
    public private(set) var lastTrigger: Trigger?
    /// Chocs et vitesses récents, pour décrire le déclenchement.
    private var peaks: [(time: TimeInterval, g: Double)] = []
    private var speeds: [(time: TimeInterval, kmh: Double)] = []
    /// Gravité de référence (téléphone sur le scooter droit), en g.
    public private(set) var reference: Vector3?

    private var lastRidingTime: TimeInterval?
    private var latestSpeedKmh: Double?
    private var impactTime: TimeInterval?
    private var tiltStart: TimeInterval?
    private var lastAlert: TimeInterval?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Mémorise la position du téléphone sur le scooter droit.
    public mutating func calibrate(gravity: Vector3) {
        guard gravity.length > 0.5 else { return }
        reference = gravity
    }

    public mutating func reset() {
        lastRidingTime = nil
        latestSpeedKmh = nil
        impactTime = nil
        tiltStart = nil
        peaks = []
        speeds = []
    }

    /// Vitesse GPS en km/h, sur la même horloge que les mesures de mouvement.
    public mutating func addSpeed(time: TimeInterval, kmh: Double) {
        guard kmh.isFinite, kmh >= 0 else { return }
        latestSpeedKmh = kmh
        speeds.append((time, kmh))
        speeds.removeAll { time - $0.time > configuration.ridingWindow }
        if kmh >= configuration.ridingSpeedKmh { lastRidingTime = time }
    }

    /// Ajoute une mesure de mouvement ; renvoie `true` une seule fois quand une
    /// chute probable est détectée.
    public mutating func addMotion(time: TimeInterval, gravity: Vector3, userAcceleration: Vector3) -> Bool {
        if reference == nil { calibrate(gravity: gravity) }
        guard let reference else { return false }
        if let lastAlert, time - lastAlert < configuration.cooldown { return false }

        let g: Double = userAcceleration.length
        if g >= 1.5 {
            peaks.append((time, g))
        }
        peaks.removeAll { time - $0.time > configuration.stopWindow + 2 }

        let wasRiding: Bool = lastRidingTime.map { time - $0 <= configuration.ridingWindow } ?? false

        // Choc violent alors qu'on roulait.
        if userAcceleration.length >= configuration.impactG, wasRiding {
            impactTime = time
        }

        // Téléphone fortement incliné, de façon durable.
        if Self.angleDegrees(reference, gravity) >= configuration.tiltDegrees {
            tiltStart = tiltStart ?? time
        } else {
            tiltStart = nil
        }

        let laidDown: Bool = wasRiding
            && (tiltStart.map { time - $0 >= configuration.tiltDuration } ?? false)

        var impactThenStop = false
        if let impactTime {
            let elapsed: TimeInterval = time - impactTime
            if elapsed > configuration.stopWindow {
                self.impactTime = nil
            } else if elapsed >= 2, let speed = latestSpeedKmh, speed <= configuration.stoppedSpeedKmh {
                impactThenStop = true
            }
        }

        guard laidDown || impactThenStop else { return false }
        lastTrigger = Trigger(
            reason: laidDown ? .laidDown : .impactThenStop,
            peakG: max(g, peaks.map(\.g).max() ?? 0),
            tiltDegrees: Self.angleDegrees(reference, gravity),
            speedBeforeKmh: speeds.map(\.kmh).max() ?? 0)
        lastAlert = time
        impactTime = nil
        tiltStart = nil
        return true
    }

    /// Angle entre deux vecteurs, en degrés.
    static func angleDegrees(_ a: Vector3, _ b: Vector3) -> Double {
        let la: Double = a.length
        let lb: Double = b.length
        guard la > 0, lb > 0 else { return 0 }
        let cosine: Double = max(-1, min(1, a.dot(b) / (la * lb)))
        return acos(cosine) * 180 / .pi
    }
}
