import Foundation

/// Alerte de dépassement d'un seuil de vitesse.
///
/// Elle se déclenche une fois au franchissement, puis ne se réarme qu'après
/// être redescendu nettement sous le seuil, pour ne pas vibrer en continu
/// quand la vitesse oscille autour de la limite.
public struct SpeedAlert: Sendable {
    /// Marge sous le seuil à repasser pour réarmer l'alerte (km/h).
    public static let hysteresis = 3.0

    /// Vrai tant que le dépassement dure : sert à colorer le compteur.
    public private(set) var isOver = false

    public init() {}

    /// Renvoie `true` à l'instant où le seuil vient d'être dépassé.
    public mutating func update(speedKmh: Double?, thresholdKmh: Double, enabled: Bool) -> Bool {
        guard enabled, let speed = speedKmh, speed.isFinite, thresholdKmh.isFinite else {
            isOver = false
            return false
        }
        if isOver {
            if speed < thresholdKmh - Self.hysteresis {
                isOver = false
            }
            return false
        }
        guard speed > thresholdKmh else { return false }
        isOver = true
        return true
    }
}
