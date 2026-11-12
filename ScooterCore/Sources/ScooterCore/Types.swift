import Foundation

/// Vecteur 3D minimal, utilisé pour la gravité et les accélérations.
public struct Vector3: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var length: Double { (x * x + y * y + z * z).squareRoot() }

    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }

    public func dot(_ o: Vector3) -> Double { x * o.x + y * o.y + z * o.z }

    public func cross(_ o: Vector3) -> Vector3 {
        Vector3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x)
    }

    public func scaled(_ k: Double) -> Vector3 { Vector3(x * k, y * k, z * k) }

    public func minus(_ o: Vector3) -> Vector3 { Vector3(x - o.x, y - o.y, z - o.z) }

    /// `nil` si le vecteur est nul (ou presque) ou contient une valeur non finie.
    public var normalized: Vector3? {
        guard isFinite else { return nil }
        let l = length
        guard l >= 1e-9 else { return nil }
        return scaled(1 / l)
    }
}

public struct Coordinate: Sendable, Equatable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Un point GPS, indépendant de CoreLocation.
public struct LocationSample: Sendable, Equatable {
    public var timestamp: TimeInterval
    public var latitude: Double
    public var longitude: Double
    /// m/s. Négatif quand la vitesse est inconnue.
    public var speed: Double
    /// m.
    public var altitude: Double
    /// m. Négatif quand la position est invalide.
    public var horizontalAccuracy: Double

    public init(timestamp: TimeInterval, latitude: Double, longitude: Double, speed: Double,
                altitude: Double, horizontalAccuracy: Double) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.speed = speed
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
    }
}

/// Un échantillon de mouvement, indépendant de CoreMotion.
/// Repère du téléphone : x vers la droite de l'écran, y vers le haut de
/// l'écran, z sortant de l'écran. Valeurs en g.
public struct MotionSample: Sendable, Equatable {
    public var timestamp: TimeInterval
    public var gravity: Vector3
    public var userAcceleration: Vector3
    /// Vitesse de rotation mesurée par le gyroscope, en rad/s.
    public var rotationRate: Vector3

    public init(timestamp: TimeInterval, gravity: Vector3, userAcceleration: Vector3,
                rotationRate: Vector3 = Vector3(0, 0, 0)) {
        self.timestamp = timestamp
        self.gravity = gravity
        self.userAcceleration = userAcceleration
        self.rotationRate = rotationRate
    }
}
