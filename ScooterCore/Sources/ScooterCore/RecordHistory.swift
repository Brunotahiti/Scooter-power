import Foundation

/// Un record établi : son temps, sa date et le trajet qui l'a produit.
public struct RecordPoint: Sendable, Equatable {
    public let time: TimeInterval
    public let date: Date
    /// Indice du trajet dans la liste fournie à `RecordHistory.progression`.
    public let tripIndex: Int
}

/// Retrace comment chaque record a progressé au fil des trajets.
public enum RecordHistory {
    public struct Trip: Sendable {
        public let date: Date
        public let times: [SpeedInterval: TimeInterval]

        public init(date: Date, times: [SpeedInterval: TimeInterval]) {
            self.date = date
            self.times = times
        }
    }

    /// Pour chaque plage, la suite des records successifs, du plus ancien au
    /// plus récent. Le dernier point est le record actuel. L'ordre des trajets
    /// en entrée est libre.
    public static func progression(_ trips: [Trip]) -> [SpeedInterval: [RecordPoint]] {
        let chronological = trips.enumerated().sorted { $0.element.date < $1.element.date }
        var book = RecordBook()
        var result: [SpeedInterval: [RecordPoint]] = [:]
        for (index, trip) in chronological {
            for interval in SpeedInterval.all {
                guard let time = trip.times[interval] else { continue }
                switch book.submit(interval, time: time) {
                case .first, .beaten:
                    result[interval, default: []].append(RecordPoint(time: time, date: trip.date, tripIndex: index))
                case .notARecord:
                    break
                }
            }
        }
        return result
    }
}
