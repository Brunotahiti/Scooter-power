import Foundation

/// Un moment marquant d'un trajet, à placer sur la carte.
public struct TripHighlight: Sendable, Equatable, Codable {
    public enum Kind: Sendable, Equatable, Codable {
        /// Meilleur temps du trajet pour cette plage d'accélération.
        case sprint(SpeedInterval)
        /// Plus forte poussée du trajet.
        case peakAcceleration
    }

    public var kind: Kind
    /// Secondes pour un temps d'accélération, m/s² pour le pic de poussée.
    public var value: Double
    /// Où la mesure a commencé ; `nil` pour le pic de poussée.
    public var start: Coordinate?
    /// Où le seuil a été atteint, ou bien où la poussée a culminé.
    public var end: Coordinate

    public init(kind: Kind, value: Double, start: Coordinate?, end: Coordinate) {
        self.kind = kind
        self.value = value
        self.start = start
        self.end = end
    }
}
