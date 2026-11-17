import Foundation

/// Un chiffre comparable d'un trajet à l'autre.
public enum ComparisonMetric: Hashable, Sendable {
    case distance, movingDuration, totalDuration, maxSpeed, averageSpeed
    /// Meilleur temps sur une plage d'accélération (km/h ou mph).
    case interval(SpeedInterval)
    case peakAcceleration, maxLeanLeft, maxLeanRight

    // Raccourcis pour les plages en km/h.
    public static let sprint30 = ComparisonMetric.interval(.zeroTo30)
    public static let sprint50 = ComparisonMetric.interval(.zeroTo50)
    public static let sprint80 = ComparisonMetric.interval(.zeroTo80)
    public static let sprint100 = ComparisonMetric.interval(.zeroTo100)
    public static let roll90 = ComparisonMetric.interval(.fiftyTo90)
    public static let roll100 = ComparisonMetric.interval(.fiftyTo100)

    /// Toutes les lignes, dans l'ordre d'affichage, avec les plages de l'unité choisie.
    public static func all(for units: UnitSystem = .metric) -> [ComparisonMetric] {
        [.distance, .movingDuration, .totalDuration, .maxSpeed, .averageSpeed]
            + SpeedInterval.shown(for: units).map { ComparisonMetric.interval($0) }
            + [.peakAcceleration, .maxLeanLeft, .maxLeanRight]
    }

    /// La plage d'accélération correspondante, pour les lignes de chrono.
    public var interval: SpeedInterval? {
        if case .interval(let interval) = self { return interval }
        return nil
    }

    enum Preference {
        case higher, lower, neutral
    }

    /// Ce qui fait qu'une valeur est « meilleure ». Distance et durées
    /// décrivent le trajet sans le classer.
    var preference: Preference {
        switch self {
        case .distance, .movingDuration, .totalDuration:
            return .neutral
        case .interval:
            return .lower
        case .maxSpeed, .averageSpeed, .peakAcceleration, .maxLeanLeft, .maxLeanRight:
            return .higher
        }
    }

    /// Nombre de décimales à l'affichage. Deux valeurs qui s'affichent de la
    /// même façon sont à égalité.
    public var displayDigits: Int {
        switch self {
        case .distance, .interval, .peakAcceleration:
            return 1
        case .movingDuration, .totalDuration, .maxSpeed, .averageSpeed, .maxLeanLeft, .maxLeanRight:
            return 0
        }
    }

    func value(in summary: TripSummary) -> Double? {
        switch self {
        case .distance: return summary.distanceMeters
        case .movingDuration: return summary.movingDuration
        case .totalDuration: return summary.totalDuration
        case .maxSpeed: return summary.maxSpeedKmh
        case .averageSpeed: return summary.averageSpeedKmh
        case .interval(let interval): return summary.bestTimes[interval]
        case .peakAcceleration: return summary.peakAcceleration
        case .maxLeanLeft: return summary.maxLeanLeftDegrees
        case .maxLeanRight: return summary.maxLeanRightDegrees
        }
    }
}

public enum ComparisonWinner: Sendable {
    case first, second, tie, none
}

public struct ComparisonRow: Sendable, Equatable {
    public var metric: ComparisonMetric
    /// Valeur brute du premier trajet (mètres, secondes, km/h, m/s², degrés), ou `nil` si elle manque.
    public var first: Double?
    public var second: Double?
    public var winner: ComparisonWinner
}

/// Met deux trajets côte à côte, chiffre par chiffre.
public enum TripComparison {
    public static func rows(_ first: TripSummary, _ second: TripSummary,
                            units: UnitSystem = .metric) -> [ComparisonRow] {
        ComparisonMetric.all(for: units).map { metric in
            let a = metric.value(in: first)
            let b = metric.value(in: second)
            return ComparisonRow(metric: metric, first: a, second: b, winner: winner(metric, a, b))
        }
    }

    private static func winner(_ metric: ComparisonMetric, _ a: Double?, _ b: Double?) -> ComparisonWinner {
        guard metric.preference != .neutral else { return .none }
        let a = a.flatMap { $0.isFinite ? $0 : nil }
        let b = b.flatMap { $0.isFinite ? $0 : nil }
        switch (a, b) {
        case (nil, nil): return .none
        case (.some, nil): return .first
        case (nil, .some): return .second
        case let (.some(x), .some(y)):
            // Comparaison à la précision affichée.
            let scale = pow(10, Double(metric.displayDigits))
            let rx = (x * scale).rounded()
            let ry = (y * scale).rounded()
            if rx == ry { return .tie }
            let firstIsHigher = rx > ry
            return (metric.preference == .higher) == firstIsHigher ? .first : .second
        }
    }
}
