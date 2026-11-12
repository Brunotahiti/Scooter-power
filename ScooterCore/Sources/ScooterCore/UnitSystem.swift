import Foundation

/// Système d'unités de l'affichage. Les calculs restent toujours en unités
/// métriques ; seule la présentation change.
public enum UnitSystem: String, Sendable, CaseIterable {
    case metric
    case imperial

    private static let kmPerMile = 1.609344
    private static let feetPerMeter = 3.280839895

    public var speedUnit: String { self == .metric ? "km/h" : "mph" }
    public var distanceUnit: String { self == .metric ? "km" : "mi" }
    public var altitudeUnit: String { self == .metric ? "m" : "ft" }

    /// Vitesse dans l'unité affichée, à partir de km/h.
    public func speed(fromKmh kmh: Double) -> Double {
        self == .metric ? kmh : kmh / Self.kmPerMile
    }

    /// Conversion inverse : km/h à partir d'une vitesse dans l'unité affichée.
    public func kmh(fromSpeed speed: Double) -> Double {
        self == .metric ? speed : speed * Self.kmPerMile
    }

    /// Distance en kilomètres ou en miles, à partir de mètres.
    public func distance(fromMeters meters: Double) -> Double {
        self == .metric ? meters / 1000 : meters / 1000 / Self.kmPerMile
    }

    /// Altitude en mètres ou en pieds, à partir de mètres.
    public func altitude(fromMeters meters: Double) -> Double {
        self == .metric ? meters : meters * Self.feetPerMeter
    }

    /// Fin d'échelle du compteur, dans l'unité affichée.
    public var speedometerMax: Double { self == .metric ? 140 : 90 }
    /// Écart entre deux chiffres du compteur.
    public var speedometerLabelStep: Double { self == .metric ? 20 : 10 }
}
