import Foundation

/// Un record personnel battu pendant un trajet.
public struct Trophy: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case interval(SpeedInterval)
        case topSpeed
        case peakAcceleration
        case maxLean
    }

    public var kind: Kind
    /// Nouveau record : secondes, km/h, m/s² ou degrés.
    public var value: Double
    /// Ancien record.
    public var previous: Double

    public init(kind: Kind, value: Double, previous: Double) {
        self.kind = kind
        self.value = value
        self.previous = previous
    }

    /// Amélioration en pourcentage, toujours positive.
    public var improvementPercent: Double {
        guard previous > 0 else { return 0 }
        switch kind {
        case .interval: return (previous - value) / previous * 100
        case .topSpeed, .peakAcceleration, .maxLean: return (value - previous) / previous * 100
        }
    }
}

/// Records battus par un trajet, comparé à tous les trajets précédents.
public enum TripTrophies {
    /// Un premier chrono ou un premier trajet ne compte pas : il faut battre un record existant,
    /// et la différence doit se voir à l'affichage.
    public static func compute(trip: TripSummary, history: [TripSummary]) -> [Trophy] {
        var trophies: [Trophy] = []

        let bestTimes = RecordBook.best(of: history.map(\.bestTimes))
        for interval in SpeedInterval.all {
            guard let value = trip.bestTimes[interval], let previous = bestTimes[interval],
                  isValid(value), round(value, 1) < round(previous, 1)
            else { continue }
            trophies.append(Trophy(kind: .interval(interval), value: value, previous: previous))
        }

        func higher(_ kind: Trophy.Kind, _ value: Double, _ past: [Double], digits: Int) {
            let valid = past.filter(isValid)
            guard isValid(value), let previous = valid.max(), round(value, digits) > round(previous, digits) else { return }
            trophies.append(Trophy(kind: kind, value: value, previous: previous))
        }
        higher(.topSpeed, trip.maxSpeedKmh, history.map(\.maxSpeedKmh), digits: 0)
        higher(.peakAcceleration, trip.peakAcceleration, history.map(\.peakAcceleration), digits: 1)
        higher(.maxLean, max(trip.maxLeanLeftDegrees, trip.maxLeanRightDegrees),
               history.map { max($0.maxLeanLeftDegrees, $0.maxLeanRightDegrees) }, digits: 0)
        return trophies
    }

    private static func isValid(_ value: Double) -> Bool {
        value.isFinite && value > 0
    }

    /// Arrondi à la précision affichée.
    private static func round(_ value: Double, _ digits: Int) -> Double {
        let scale = pow(10, Double(digits))
        return (value * scale).rounded() / scale
    }
}
