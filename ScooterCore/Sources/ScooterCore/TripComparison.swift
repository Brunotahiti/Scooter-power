import Foundation

/// Un chiffre comparable d'un trajet à l'autre.
public enum ComparisonMetric: CaseIterable, Sendable {
    case distance, movingDuration, totalDuration, maxSpeed, averageSpeed
    case sprint30, sprint50, sprint80, sprint100, roll90, roll100
    case peakAcceleration, maxLeanLeft, maxLeanRight

    /// La plage d'accélération correspondante, pour les lignes de chrono.
    public var interval: SpeedInterval? {
        switch self {
        case .sprint30: return .zeroTo30
        case .sprint50: return .zeroTo50
        case .sprint80: return .zeroTo80
        case .sprint100: return .zeroTo100
        case .roll90: return .fiftyTo90
        case .roll100: return .fiftyTo100
        default: return nil
        }
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
        case .sprint30, .sprint50, .sprint80, .sprint100, .roll90, .roll100:
            return .lower
        case .maxSpeed, .averageSpeed, .peakAcceleration, .maxLeanLeft, .maxLeanRight:
            return .higher
        }
    }

    /// Nombre de décimales à l'affichage. Deux valeurs qui s'affichent de la
    /// même façon sont à égalité.
    public var displayDigits: Int {
        switch self {
        case .distance, .sprint30, .sprint50, .sprint80, .sprint100, .roll90, .roll100, .peakAcceleration:
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
        case .sprint30, .sprint50, .sprint80, .sprint100, .roll90, .roll100:
            return interval.flatMap { summary.bestTimes[$0] }
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
    public static func rows(_ first: TripSummary, _ second: TripSummary) -> [ComparisonRow] {
        ComparisonMetric.allCases.map { metric in
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
