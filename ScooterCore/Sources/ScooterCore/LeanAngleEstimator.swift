import Foundation

public enum LeanSide: Sendable {
    case left, upright, right
}

/// Inclinaison lissée du scooter par rapport à la position de calibration.
///
/// Limite physique : en virage équilibré, la gravité apparente reste alignée
/// avec le scooter, donc l'angle mesuré est inférieur à l'inclinaison réelle.
public struct LeanAngleEstimator: Sendable {
    public static let timeConstant = 0.2
    public static let maxAngle = 60.0
    public static let uprightThreshold = 1.0
    /// Au-delà de cet écart entre deux échantillons, le filtre repart de la nouvelle valeur.
    public static let maxGap = 1.0

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

    /// Prend la gravité courante comme position verticale et remet les maxima à zéro.
    /// Renvoie `false`, sans rien changer, si la gravité est inutilisable.
    @discardableResult
    public mutating func calibrate(gravity: Vector3) -> Bool {
        guard let new = MountCalibration(gravity: gravity) else { return false }
        calibration = new
        angleDegrees = 0
        maxLeftDegrees = 0
        maxRightDegrees = 0
        lastTimestamp = nil
        return true
    }

    /// `trackExtremes` à `false` met à jour l'angle sans toucher aux maxima (trajet en pause).
    public mutating func update(gravity: Vector3, timestamp: TimeInterval, trackExtremes: Bool = true) {
        guard let calibration, gravity.isFinite, gravity.length >= 0.1, timestamp.isFinite else { return }
        let raw = calibration.leanAngleDegrees(gravity: gravity)

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
