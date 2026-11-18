import Foundation
import SwiftData
import ScooterCore

/// Un segment enregistré : une portion de route chronométrée à chaque passage.
@Model
final class SegmentRecord {
    var uid: String
    var name: String
    var createdAt: Date
    var lengthMeters: Double
    @Attribute(.externalStorage) var pathData: Data

    init(name: String, segment: Segment) {
        self.uid = UUID().uuidString
        self.name = name
        self.createdAt = Date()
        self.lengthMeters = segment.length
        self.pathData = (try? JSONEncoder().encode(segment)) ?? Data()
    }

    var segment: Segment? {
        try? JSONDecoder().decode(Segment.self, from: pathData)
    }
}

/// Un passage d'un trajet sur un segment.
struct SegmentEffort: Identifiable {
    let trip: TripRecord
    let pass: Segment.Pass
    var id: String { "\(trip.persistentModelID.hashValue)-\(pass.startIndex)" }
    var duration: TimeInterval { pass.duration }
}

extension TripRecord {
    /// Vrais temps de chaque point du tracé ; `nil` pour les trajets anciens
    /// (sans temps enregistrés), qui ne sont pas chronométrés sur les segments.
    var recordedTimes: [TimeInterval]? {
        let points: [ReplayPoint] = replayPoints
        guard points.count == route.count, points.count > 1 else { return nil }
        var times: [TimeInterval] = []
        for point in points {
            times.append(max(point.time, times.last ?? point.time))
        }
        return times
    }
}

extension SegmentRecord {
    /// Tous les passages de ces trajets, du plus rapide au plus lent.
    func efforts(in trips: [TripRecord]) -> [SegmentEffort] {
        guard let segment else { return [] }
        var result: [SegmentEffort] = []
        for trip in trips {
            guard let times = trip.recordedTimes else { continue }
            let route: [Coordinate] = trip.route
            for pass in segment.passes(route: route, times: times) {
                result.append(SegmentEffort(trip: trip, pass: pass))
            }
        }
        return result.sorted { $0.duration < $1.duration }
    }
}

/// Après un trajet : annonce les segments parcourus et les records battus.
@MainActor
enum SegmentAnnouncer {
    static func check(trip: TripRecord, segments: [SegmentRecord], previousTrips: [TripRecord]) {
        guard let times = trip.recordedTimes else { return }
        var sentences: [String] = []
        for record in segments {
            guard let segment = record.segment, let pass = segment.bestPass(route: trip.route, times: times) else { continue }
            let previousBest: TimeInterval? = record.efforts(in: previousTrips).first?.duration
            let time: String = SegmentFormat.duration(pass.duration)
            if let previousBest, pass.duration < previousBest {
                sentences.append(L("Record sur \(record.name) : \(time) !"))
            } else if previousBest == nil {
                sentences.append(L("Premier passage sur \(record.name) : \(time)."))
            } else {
                sentences.append(L("\(record.name) : \(time)."))
            }
        }
        guard !sentences.isEmpty, AppSettings.shared.voiceEnabled else { return }
        Announcer.shared.say(sentences.joined(separator: " "))
    }
}

enum SegmentFormat {
    /// « 48,3 s » ou « 1:02,4 ».
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return Formatters.decimal(seconds, digits: 1) + " s" }
        let minutes = Int(seconds) / 60
        let rest: Double = seconds - Double(minutes * 60)
        let restText: String = Formatters.decimal(rest, digits: 1)
        return "\(minutes):" + (rest < 10 ? "0" : "") + restText
    }
}
