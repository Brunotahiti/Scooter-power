import Foundation

/// Détecte une chute probable pendant un trajet, à partir des capteurs du
/// téléphone fixé au guidon et de la vitesse GPS.
///
/// Deux scénarios déclenchent l'alerte, toujours juste après avoir roulé :
/// - **scooter couché** : le téléphone reste incliné de plus de `tiltDegrees`
///   par rapport au scooter droit pendant `tiltDuration` secondes, le scooter
///   arrêté, et cette inclinaison a commencé moins de `ridingWindow` secondes
///   après avoir roulé (aucun scooter ne roule penché à plus de 65°) ;
/// - **choc, arrêt et scooter penché** : un choc franc (moyenne d'au moins
///   `impactG` sur 0,15 s, pas une simple pointe de vibration), puis l'arrêt
///   et une inclinaison d'au moins `impactTiltDegrees` maintenue.
///
/// Ne déclenchent rien : vibrations et nids-de-poule, freinage d'urgence ou
/// arrêt à un feu (le scooter reste droit), béquille, téléphone pris en main
/// à l'arrêt. La position de référence se recale toute seule en roulant, au
/// cas où le trajet aurait démarré téléphone en main.
public struct CrashDetector: Sendable {
    public struct Configuration: Sendable {
        /// Choc minimal, en g, en moyenne sur `impactWindow` (gravité retirée).
        public var impactG: Double = 3.5
        public var impactWindow: TimeInterval = 0.15
        /// Inclinaison du téléphone qui signe un scooter couché.
        public var tiltDegrees: Double = 65
        /// Durée pendant laquelle elle doit persister, scooter arrêté (s).
        public var tiltDuration: TimeInterval = 4
        /// Après un choc, inclinaison suffisante pour confirmer la chute.
        public var impactTiltDegrees: Double = 45
        public var impactTiltDuration: TimeInterval = 1.5
        /// Vitesse au-dessus de laquelle on « roulait » (km/h).
        public var ridingSpeedKmh: Double = 20
        /// L'inclinaison ou le choc doivent survenir moins de ce délai après avoir roulé (s).
        public var ridingWindow: TimeInterval = 5
        /// Vitesse sous laquelle on est arrêté (km/h).
        public var stoppedSpeedKmh: Double = 5
        /// Après un choc, délai pendant lequel on attend l'arrêt et l'inclinaison (s).
        public var stopWindow: TimeInterval = 10
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
    /// Gravité de référence (téléphone sur le scooter droit), en g, normalisée.
    public private(set) var reference: Vector3?

    private var lastRidingTime: TimeInterval?
    private var latestSpeedKmh: Double?
    private var impactTime: TimeInterval?
    private var tiltStart: TimeInterval?
    /// L'inclinaison a commencé peu après avoir roulé.
    private var tiltAfterRiding = false
    private var impactTiltStart: TimeInterval?
    private var lastAlert: TimeInterval?
    private var lastMotionTime: TimeInterval?
    /// Mesures récentes du choc, pour la moyenne glissante.
    private var window: [(time: TimeInterval, g: Double)] = []
    private var peaks: [(time: TimeInterval, g: Double)] = []
    private var speeds: [(time: TimeInterval, kmh: Double)] = []

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Mémorise la position du téléphone sur le scooter droit.
    public mutating func calibrate(gravity: Vector3) {
        let length: Double = gravity.length
        guard length > 0.5 else { return }
        reference = gravity.scaled(1 / length)
    }

    public mutating func reset() {
        lastRidingTime = nil
        latestSpeedKmh = nil
        impactTime = nil
        tiltStart = nil
        impactTiltStart = nil
        tiltAfterRiding = false
        lastMotionTime = nil
        window = []
        peaks = []
        speeds = []
    }

    /// Vitesse GPS en km/h, sur la même horloge que les mesures de mouvement.
    public mutating func addSpeed(time: TimeInterval, kmh: Double) {
        guard kmh.isFinite, kmh >= 0 else { return }
        latestSpeedKmh = kmh
        if kmh >= configuration.ridingSpeedKmh { lastRidingTime = time }
        speeds.append((time, kmh))
        speeds.removeAll { time - $0.time > 12 }
    }

    /// Ajoute une mesure de mouvement ; renvoie `true` une seule fois quand une
    /// chute probable est détectée.
    public mutating func addMotion(time: TimeInterval, gravity: Vector3, userAcceleration: Vector3) -> Bool {
        if reference == nil { calibrate(gravity: gravity) }
        guard let reference else { return false }
        let g: Double = userAcceleration.length
        let speed: Double = latestSpeedKmh ?? 0

        // En roulant, sans secousse : la référence suit lentement la position
        // réelle du téléphone (constante de temps de 4 s).
        let step: Double = lastMotionTime.map { min(1, max(0, time - $0)) } ?? 0
        lastMotionTime = time
        if speed >= configuration.ridingSpeedKmh, g < 0.5, gravity.length > 0.5, step > 0 {
            let k: Double = min(1, step / 4)
            calibrate(gravity: reference.scaled(1 - k).plus(gravity.scaled(k / gravity.length)))
        }

        if let lastAlert, time - lastAlert < configuration.cooldown { return false }
        let recentlyRiding: Bool = lastRidingTime.map { time - $0 <= configuration.ridingWindow } ?? false
        let stopped: Bool = speed <= configuration.stoppedSpeedKmh
        let tilt: Double = Self.angleDegrees(reference, gravity)

        // Choc franc : moyenne sur une courte fenêtre, pas une pointe isolée.
        window.append((time, g))
        window.removeAll { time - $0.time > configuration.impactWindow }
        if g >= 1.5 { peaks.append((time, g)) }
        peaks.removeAll { time - $0.time > configuration.stopWindow + 2 }
        let average: Double = window.reduce(0) { $0 + $1.g } / Double(window.count)
        if window.count >= 3, average >= configuration.impactG, recentlyRiding {
            impactTime = time
        }

        // Scooter couché : inclinaison forte, commencée juste après avoir roulé.
        if tilt >= configuration.tiltDegrees {
            if tiltStart == nil {
                tiltStart = time
                tiltAfterRiding = recentlyRiding
            }
        } else {
            tiltStart = nil
            tiltAfterRiding = false
        }
        let laidDown: Bool = tiltAfterRiding && stopped
            && (tiltStart.map { time - $0 >= configuration.tiltDuration } ?? false)

        // Choc, puis arrêt avec le scooter penché.
        var impactThenStop = false
        if let impactTime {
            if time - impactTime > configuration.stopWindow {
                self.impactTime = nil
                impactTiltStart = nil
            } else if stopped, tilt >= configuration.impactTiltDegrees {
                impactTiltStart = impactTiltStart ?? time
                impactThenStop = time - (impactTiltStart ?? time) >= configuration.impactTiltDuration
            } else {
                impactTiltStart = nil
            }
        }

        guard laidDown || impactThenStop else { return false }
        lastTrigger = Trigger(
            reason: laidDown ? .laidDown : .impactThenStop,
            peakG: max(g, peaks.map(\.g).max() ?? 0),
            tiltDegrees: tilt,
            speedBeforeKmh: speeds.map(\.kmh).max() ?? 0)
        lastAlert = time
        impactTime = nil
        impactTiltStart = nil
        tiltStart = nil
        tiltAfterRiding = false
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
