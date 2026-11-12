import Foundation

public enum LeanSide: Sendable {
    case left, upright, right
}

/// Inclinaison lissée du scooter.
///
/// À l'arrêt et à basse vitesse, l'angle vient de la direction de la gravité
/// par rapport à la calibration. En roulant, cette mesure sous-estime
/// l'inclinaison (la force centrifuge redresse la gravité apparente) : l'angle
/// vient alors de la physique du virage, `atan(vitesse × lacet / g)`.
public struct LeanAngleEstimator: Sendable {
    public static let timeConstant = 0.2
    public static let maxAngle = 60.0
    public static let uprightThreshold = 1.0
    /// Au-delà de cet écart entre deux échantillons, le filtre repart de la nouvelle valeur.
    public static let maxGap = 1.0
    /// En dessous (m/s), mesure par gravité seule : 10 km/h.
    public static let gravityOnlyBelow = 10.0 / 3.6
    /// Au-dessus (m/s), mesure physique seule : 25 km/h.
    public static let physicsOnlyAbove = 25.0 / 3.6

    /// Inclinaison d'équilibre en virage, en degrés. Positive à droite pour
    /// un lacet positif (virage à droite).
    ///
    /// `yawRate` est mesuré autour de l'axe vertical *du scooter*, qui penche
    /// avec lui : le gyroscope n'y voit que `lacet au sol × cos(angle)`. Comme
    /// `tan(angle) = v × lacet au sol / g`, il vient `sin(angle) = v × yawRate / g`.
    public static func physicalLeanDegrees(speed: Double, yawRate: Double) -> Double {
        guard speed.isFinite, yawRate.isFinite, speed > 0 else { return 0 }
        let sine = speed * yawRate / MountCalibration.standardGravity
        return asin(min(1, max(-1, sine))) * 180 / .pi
    }

    /// Part de la mesure physique dans le résultat, de 0 à 1.
    public static func physicsWeight(speed: Double?) -> Double {
        guard let speed, speed.isFinite else { return 0 }
        let ratio = (speed - gravityOnlyBelow) / (physicsOnlyAbove - gravityOnlyBelow)
        return min(1, max(0, ratio))
    }

    public private(set) var calibration: MountCalibration?
    /// Lissé, borné à ±60°. Positif vers la droite.
    public private(set) var angleDegrees: Double = 0
    public private(set) var maxLeftDegrees: Double = 0
    public private(set) var maxRightDegrees: Double = 0

    private var lastTimestamp: TimeInterval?

    public init() {}

    public var side: LeanSide {
        if angleDegrees >= Self.uprightThreshold { return .right }
        if angleDegrees <= -Self.uprightThreshold { return .left }
        return .upright
    }

    /// Prend la gravité courante comme position verticale. Les maxima du trajet
    /// sont conservés : recalibrer en route ne les efface pas.
    /// Renvoie `false`, sans rien changer, si la gravité est inutilisable.
    @discardableResult
    public mutating func calibrate(gravity: Vector3) -> Bool {
        guard let new = MountCalibration(gravity: gravity) else { return false }
        calibration = new
        angleDegrees = 0
        lastTimestamp = nil
        return true
    }

    /// - Parameters:
    ///   - rotationRate: gyroscope, en rad/s, dans le repère du téléphone.
    ///   - speed: dernière vitesse GPS en m/s, ou `nil` si elle est inconnue.
    ///   - trackExtremes: à `false`, met à jour l'angle sans toucher aux maxima (trajet en pause).
    public mutating func update(gravity: Vector3, timestamp: TimeInterval,
                                rotationRate: Vector3 = Vector3(0, 0, 0), speed: Double? = nil,
                                trackExtremes: Bool = true) {
        guard let calibration, gravity.isFinite, gravity.length >= 0.1, timestamp.isFinite else { return }

        var raw = calibration.leanAngleDegrees(gravity: gravity)
        let weight = Self.physicsWeight(speed: speed)
        if weight > 0, let speed, rotationRate.isFinite {
            // Lacet autour de l'axe vertical du scooter, fixé à la calibration : il ne
            // dépend pas de l'estimation de gravité, qui dérive en virage prolongé.
            // Positif en virage à droite.
            let yawRate = rotationRate.dot(calibration.down)
            let physical = Self.physicalLeanDegrees(speed: speed, yawRate: yawRate)
            raw = (1 - weight) * raw + weight * physical
        }

        if let last = lastTimestamp, timestamp - last > 0, timestamp - last <= Self.maxGap {
            let dt = timestamp - last
            angleDegrees += (raw - angleDegrees) * dt / (Self.timeConstant + dt)
        } else {
            angleDegrees = raw
        }
        angleDegrees = min(Self.maxAngle, max(-Self.maxAngle, angleDegrees))
        lastTimestamp = timestamp

        if trackExtremes {
            maxRightDegrees = max(maxRightDegrees, angleDegrees)
            maxLeftDegrees = max(maxLeftDegrees, -angleDegrees)
        }
    }
}
