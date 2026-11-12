import Foundation

/// Les records d'accélération, tous trajets confondus.
public struct RecordBook: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        /// Pas mieux que le record, ou temps invalide.
        case notARecord
        /// Premier temps pour cette plage : il devient le record sans en battre un.
        case first
        /// Record battu ; `previous` est l'ancien.
        case beaten(previous: TimeInterval)
    }

    /// Meilleur temps connu pour chaque plage, en secondes.
    public private(set) var records: [SpeedInterval: TimeInterval]

    public init(records: [SpeedInterval: TimeInterval] = [:]) {
        self.records = records.filter { Self.isValid($0.value) }
    }

    /// Propose un temps. Le record n'est battu que si la différence se voit à
    /// l'affichage, au dixième de seconde.
    public mutating func submit(_ interval: SpeedInterval, time: TimeInterval) -> Outcome {
        guard Self.isValid(time) else { return .notARecord }
        guard let previous = records[interval] else {
            records[interval] = time
            return .first
        }
        guard Self.tenths(time) < Self.tenths(previous) else { return .notARecord }
        records[interval] = time
        return .beaten(previous: previous)
    }

    /// Intègre d'autres temps sans rien annoncer : seuls les meilleurs restent.
    public mutating func merge(_ other: [SpeedInterval: TimeInterval]) {
        records = Self.best(of: [records, other])
    }

    /// Meilleur temps valide de chaque plage parmi plusieurs trajets.
    public static func best(of trips: [[SpeedInterval: TimeInterval]]) -> [SpeedInterval: TimeInterval] {
        var result: [SpeedInterval: TimeInterval] = [:]
        for times in trips {
            for (interval, time) in times where isValid(time) {
                result[interval] = min(result[interval] ?? time, time)
            }
        }
        return result
    }

    private static func isValid(_ time: TimeInterval) -> Bool {
        time.isFinite && time > 0
    }

    private static func tenths(_ time: TimeInterval) -> Double {
        (time * 10).rounded()
    }
}
