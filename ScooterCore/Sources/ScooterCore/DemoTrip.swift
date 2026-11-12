import Foundation

/// Trajet synthétique, déterministe et continu, pour le mode démo.
/// `t` est le nombre de secondes écoulées depuis le début de la démo.
public struct DemoTrip: Sendable {
    private static let startLatitude = 48.8566
    private static let startLongitude = 2.3522
    private static let metersPerDegree = 111_195.0

    public init() {}

    private func speed(at t: TimeInterval) -> Double {
        13 + 9 * sin(t / 11) + 4 * sin(t / 3.7)
    }

    private func acceleration(at t: TimeInterval) -> Double {
        9.0 / 11 * cos(t / 11) + 4.0 / 3.7 * cos(t / 3.7)
    }

    /// Intégrale de `speed` depuis 0 : distance parcourue vers l'est, en mètres.
    private func travelled(at t: TimeInterval) -> Double {
        13 * t + 99 * (1 - cos(t / 11)) + 14.8 * (1 - cos(t / 3.7))
    }

    public func location(at t: TimeInterval) -> LocationSample {
        let metersPerLongitudeDegree = Self.metersPerDegree * cos(Self.startLatitude * .pi / 180)
        return LocationSample(
            timestamp: t,
            latitude: Self.startLatitude,
            longitude: Self.startLongitude + travelled(at: t) / metersPerLongitudeDegree,
            speed: min(30, max(0, speed(at: t))),
            altitude: 24 + 3 * sin(t / 40),
            horizontalAccuracy: 5)
    }

    public func motion(at t: TimeInterval) -> MotionSample {
        let lean = 12 * sin(t / 6) * .pi / 180
        let gravity = Vector3(sin(lean), -cos(lean), 0)
        // Lacet cohérent avec l'inclinaison : celui d'un virage équilibré à cette vitesse.
        let yawRate = MountCalibration.standardGravity * tan(lean) / max(1, speed(at: t))
        return MotionSample(
            timestamp: t,
            gravity: gravity,
            userAcceleration: Vector3(0, 0, -acceleration(at: t) / MountCalibration.standardGravity),
            rotationRate: gravity.scaled(yawRate))
    }
}
