import Foundation

/// Un chiffre de performance comparable entre deux configurations du scooter.
public enum StatMetric: Hashable, Sendable {
    case topSpeed
    case averageTopSpeed
    case overallAverageSpeed
    case bestPeakAcceleration
    case averagePeakAcceleration
    /// Meilleur temps d'une plage d'accélération.
    case intervalBest(SpeedInterval)
    /// Temps moyen d'une plage d'accélération.
    case intervalAverage(SpeedInterval)
    case maxLean

    /// Vrai pour les temps : une valeur plus basse est meilleure.
    public var lowerIsBetter: Bool {
        switch self {
        case .intervalBest, .intervalAverage: return true
        default: return false
        }
    }

    /// Toutes les lignes, dans l'ordre d'affichage.
    public static var all: [StatMetric] {
        var list: [StatMetric] = [
            .topSpeed, .averageTopSpeed, .overallAverageSpeed, .bestPeakAcceleration, .averagePeakAcceleration,
        ]
        for interval in SpeedInterval.all {
            list.append(.intervalBest(interval))
            list.append(.intervalAverage(interval))
        }
        list.append(.maxLean)
        return list
    }

    /// Valeur brute (km/h, m/s², secondes, degrés), ou `nil` sans donnée.
    func value(in stats: PerformanceStats) -> Double? {
        let raw: Double?
        switch self {
        case .topSpeed: raw = stats.topSpeedKmh
        case .averageTopSpeed: raw = stats.averageTopSpeedKmh
        case .overallAverageSpeed: raw = stats.overallAverageSpeedKmh
        case .bestPeakAcceleration: raw = stats.bestPeakAcceleration
        case .averagePeakAcceleration: raw = stats.averagePeakAcceleration
        case .intervalBest(let interval): raw = stats.intervals[interval]?.best
        case .intervalAverage(let interval): raw = stats.intervals[interval]?.average
        case .maxLean: raw = max(stats.maxLeanLeftDegrees, stats.maxLeanRightDegrees)
        }
        // Zéro signifie « jamais mesuré », pas une vraie valeur.
        guard let raw, raw.isFinite, raw > 0 else { return nil }
        return raw
    }
}

public enum StatVerdict: Sendable {
    case better, worse, same, unknown
}

/// L'écart d'un chiffre entre la configuration de référence et la modifiée.
public struct StatDelta: Sendable, Equatable {
    public var metric: StatMetric
    public var baseline: Double?
    public var modified: Double?
    /// Variation en pourcentage de la référence vers la modifiée ; `nil` si
    /// l'une des deux valeurs manque.
    public var percent: Double?
    public var verdict: StatVerdict
}

/// Compare les performances de deux configurations du scooter.
public enum PerformanceComparison {
    /// En dessous de cet écart, en pourcentage, les deux valeurs sont jugées égales.
    public static let sameThreshold = 0.5

    public static func deltas(baseline: PerformanceStats, modified: PerformanceStats) -> [StatDelta] {
        StatMetric.all.map { metric in
            let a = metric.value(in: baseline)
            let b = metric.value(in: modified)
            guard let a, let b else {
                return StatDelta(metric: metric, baseline: a, modified: b, percent: nil, verdict: .unknown)
            }
            let percent = (b - a) / a * 100
            let verdict: StatVerdict
            if abs(percent) < sameThreshold {
                verdict = .same
            } else {
                let improved = metric.lowerIsBetter ? percent < 0 : percent > 0
                verdict = improved ? .better : .worse
            }
            return StatDelta(metric: metric, baseline: a, modified: b, percent: percent, verdict: verdict)
        }
    }
}
