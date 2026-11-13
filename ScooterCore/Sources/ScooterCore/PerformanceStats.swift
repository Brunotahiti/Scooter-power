import Foundation

/// Statistiques de performance sur l'ensemble des trajets.
public struct PerformanceStats: Sendable, Equatable {
    /// Temps d'une plage d'accélération sur tous les trajets qui l'ont mesurée.
    public struct IntervalStats: Sendable, Equatable {
        /// Meilleur temps, en secondes.
        public var best: TimeInterval
        /// Moyenne des meilleurs temps de chaque trajet.
        public var average: TimeInterval
        /// Moins bon des meilleurs temps.
        public var worst: TimeInterval
        /// Nombre de trajets ayant un temps pour cette plage.
        public var count: Int

        public init(best: TimeInterval, average: TimeInterval, worst: TimeInterval, count: Int) {
            self.best = best
            self.average = average
            self.worst = worst
            self.count = count
        }
    }

    public var tripCount = 0
    public var totalDistanceMeters: Double = 0
    public var totalMovingDuration: TimeInterval = 0
    public var totalDuration: TimeInterval = 0

    /// Vitesse la plus élevée jamais atteinte.
    public var topSpeedKmh: Double = 0
    /// Moyenne des vitesses maximales des trajets où le scooter a roulé.
    public var averageTopSpeedKmh: Double = 0
    /// Distance totale divisée par le temps de roulage total.
    public var overallAverageSpeedKmh: Double = 0
    /// Meilleure vitesse moyenne obtenue sur un trajet.
    public var bestTripAverageSpeedKmh: Double = 0

    /// Plus forte poussée jamais mesurée, en m/s².
    public var bestPeakAcceleration: Double = 0
    /// Moyenne des pics d'accélération des trajets où le scooter a roulé.
    public var averagePeakAcceleration: Double = 0

    public var maxLeanLeftDegrees: Double = 0
    public var maxLeanRightDegrees: Double = 0
    /// Moyenne de l'inclinaison maximale de chaque trajet, tous côtés confondus.
    public var averageMaxLeanDegrees: Double = 0

    public var intervals: [SpeedInterval: IntervalStats] = [:]

    public init(trips: [TripSummary]) {
        tripCount = trips.count

        var topSpeeds: [Double] = []
        var peaks: [Double] = []
        var leans: [Double] = []
        var times: [SpeedInterval: [TimeInterval]] = [:]

        for trip in trips {
            let distance = Self.clean(trip.distanceMeters)
            let moving = Self.clean(trip.movingDuration)
            totalDistanceMeters += distance
            totalMovingDuration += moving
            totalDuration += Self.clean(trip.totalDuration)

            let top = Self.clean(trip.maxSpeedKmh)
            let peak = Self.clean(trip.peakAcceleration)
            let left = Self.clean(trip.maxLeanLeftDegrees)
            let right = Self.clean(trip.maxLeanRightDegrees)

            topSpeedKmh = max(topSpeedKmh, top)
            bestPeakAcceleration = max(bestPeakAcceleration, peak)
            maxLeanLeftDegrees = max(maxLeanLeftDegrees, left)
            maxLeanRightDegrees = max(maxLeanRightDegrees, right)
            if moving > 0 {
                bestTripAverageSpeedKmh = max(bestTripAverageSpeedKmh, distance / moving * 3.6)
            }

            // Un trajet resté à l'arrêt ne compte pas dans les moyennes.
            if top > 0 {
                topSpeeds.append(top)
                peaks.append(peak)
                leans.append(max(left, right))
            }

            for (interval, time) in trip.bestTimes where time.isFinite && time > 0 {
                times[interval, default: []].append(time)
            }
        }

        averageTopSpeedKmh = Self.mean(topSpeeds)
        averagePeakAcceleration = Self.mean(peaks)
        averageMaxLeanDegrees = Self.mean(leans)
        if totalMovingDuration > 0 {
            overallAverageSpeedKmh = totalDistanceMeters / totalMovingDuration * 3.6
        }

        for (interval, values) in times {
            guard let best = values.min(), let worst = values.max() else { continue }
            intervals[interval] = IntervalStats(
                best: best, average: Self.mean(values), worst: worst, count: values.count)
        }
    }

    /// Valeur utilisable : finie et positive, sinon 0.
    private static func clean(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : 0
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}
