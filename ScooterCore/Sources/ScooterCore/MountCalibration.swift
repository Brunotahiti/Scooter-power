import Foundation

/// Repère du support, fixé au moment de la calibration : où est le bas, et
/// où est l'avant du scooter, exprimés dans le repère du téléphone.
public struct MountCalibration: Sendable, Equatable {
    public static let standardGravity = 9.80665

    /// Gravité de référence, unitaire.
    public let down: Vector3
    /// Sens de marche, unitaire et orthogonal à `down`.
    public let forward: Vector3

    /// `nil` si la gravité est non finie ou trop faible pour définir un bas.
    public init?(gravity: Vector3) {
        guard gravity.isFinite, gravity.length >= 0.1, let down = gravity.normalized else { return nil }

        // Téléphone face au pilote : l'avant est le dos de l'écran, ramené à l'horizontale.
        let back = Vector3(0, 0, -1)
        var candidate = back.minus(down.scaled(back.dot(down)))
        if candidate.length < 0.2 {
            // Téléphone à plat : l'avant est le haut de l'écran.
            let top = Vector3(0, 1, 0)
            candidate = top.minus(down.scaled(top.dot(down)))
        }
        guard let forward = candidate.normalized else { return nil }

        self.down = down
        self.forward = forward
    }

    /// Rotation autour de l'axe de marche depuis la calibration, en degrés.
    /// Positif vers la droite. 0 si la gravité est inutilisable.
    public func leanAngleDegrees(gravity: Vector3) -> Double {
        guard gravity.isFinite else { return 0 }
        let a = down.minus(forward.scaled(down.dot(forward)))
        let b = gravity.minus(forward.scaled(gravity.dot(forward)))
        guard b.length >= 1e-6 else { return 0 }
        let sine = -forward.dot(a.cross(b))
        let cosine = a.dot(b)
        return atan2(sine, cosine) * 180 / .pi
    }

    /// Accélération le long du sens de marche, en m/s². Positif en accélération.
    public func longitudinalAcceleration(userAccelerationG: Vector3) -> Double {
        guard userAccelerationG.isFinite else { return 0 }
        return userAccelerationG.dot(forward) * Self.standardGravity
    }
}
