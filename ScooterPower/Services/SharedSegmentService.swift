import CloudKit
import Foundation
import ScooterCore

/// Segments partagés : publiés dans la base publique iCloud, avec un temps
/// par pilote. Le meilleur temps d'un segment est le « Roi de la route ».
/// Les temps ne sont publiés que si le pilote a accepté les classements.
@MainActor
enum SharedSegmentService {
    private static let segmentType = "SharedSegment"
    private static let timeType = "SegmentTime"
    private static let submittedKey = "segmentTimesSubmitted"
    private static let crownsKey = "segmentCrowns"

    struct Remote: Identifiable, Equatable {
        let id: String
        let name: String
        let path: [Coordinate]
        let lengthMeters: Double
        let creator: String
    }

    struct Ranked: Identifiable, Equatable {
        let id: String
        let rider: String
        let model: String
        let seconds: TimeInterval
        let date: Date
        let isMe: Bool
    }

    private static var database: CKDatabase {
        CKContainer(identifier: GroupRideService.containerID).publicCloudDatabase
    }

    private static var myID: String { GroupRideService.shared.myID }

    private static var riderName: String {
        let name: String = AppSettings.shared.riderName
        return name.isEmpty ? L("Pilote") : name
    }

    // MARK: - Segments

    /// Publie un segment créé sur cet iPhone ; il devient visible des pilotes de la région.
    static func publish(_ record: SegmentRecord) async throws {
        guard let segment = record.segment, let start = segment.path.first else { return }
        let ckRecord = CKRecord(recordType: segmentType, recordID: CKRecord.ID(recordName: record.uid))
        ckRecord["name"] = record.name as CKRecordValue
        ckRecord["path"] = SharedSegments.encodePath(segment.path) as CKRecordValue
        ckRecord["lengthMeters"] = record.lengthMeters as CKRecordValue
        ckRecord["cell"] = SharedSegments.cell(for: start) as CKRecordValue
        ckRecord["creator"] = riderName as CKRecordValue
        ckRecord["createdAt"] = Date() as CKRecordValue
        _ = try await database.modifyRecords(saving: [ckRecord], deleting: [], savePolicy: .allKeys)
        record.remoteID = record.uid
        record.creator = riderName
    }

    /// Segments partagés autour des départs des derniers trajets.
    static func nearby(trips: [TripRecord]) async throws -> [Remote] {
        let starts: [Coordinate] = trips.sorted { $0.startDate > $1.startDate }.prefix(20).compactMap { $0.route.first }
        let cells: [String] = SharedSegments.cells(around: starts)
        guard !cells.isEmpty else { return [] }
        let query = CKQuery(recordType: segmentType, predicate: NSPredicate(format: "cell IN %@", cells))
        let (results, _) = try await database.records(matching: query, resultsLimit: 100)
        return results.compactMap { entry -> Remote? in
            guard let record = try? entry.1.get(), let name = record["name"] as? String,
                  let pathText = record["path"] as? String else { return nil }
            let path: [Coordinate] = SharedSegments.decodePath(pathText)
            guard path.count >= 2 else { return nil }
            return Remote(id: entry.0.recordName, name: name, path: path,
                          lengthMeters: record["lengthMeters"] as? Double ?? Segment(path: path).length,
                          creator: record["creator"] as? String ?? L("Pilote"))
        }
    }

    // MARK: - Temps

    /// Classement d'un segment, du plus rapide au plus lent.
    static func leaderboard(segmentID: String, lengthMeters: Double) async throws -> [Ranked] {
        let query = CKQuery(recordType: timeType, predicate: NSPredicate(format: "segmentID == %@", segmentID))
        query.sortDescriptors = [NSSortDescriptor(key: "seconds", ascending: true)]
        let (results, _) = try await database.records(matching: query, resultsLimit: 50)
        let mine: String = SharedSegments.timeRecordName(segmentID: segmentID, riderID: myID)
        let rows: [Ranked] = results.compactMap { entry -> Ranked? in
            guard let record = try? entry.1.get(), let seconds = record["seconds"] as? Double,
                  SharedSegments.isPlausible(seconds: seconds, lengthMeters: lengthMeters) else { return nil }
            return Ranked(id: entry.0.recordName, rider: record["rider"] as? String ?? L("Pilote"),
                          model: record["model"] as? String ?? "", seconds: seconds,
                          date: record["date"] as? Date ?? Date(), isMe: entry.0.recordName == mine)
        }
        .sorted { $0.seconds < $1.seconds }
        rememberCrown(segmentID: segmentID, rows: rows)
        return rows
    }

    /// Publie mes meilleurs temps sur les segments partagés, s'ils s'améliorent.
    static func submit(segments: [SegmentRecord], trips: [TripRecord], model: String) {
        guard AppSettings.shared.leaderboardEnabled else { return }
        var submitted: [String: Double] = UserDefaults.standard.dictionary(forKey: submittedKey) as? [String: Double] ?? [:]
        var records: [CKRecord] = []
        for segment in segments {
            guard let remoteID = segment.remoteID, let best = segment.efforts(in: trips).first,
                  SharedSegments.isPlausible(seconds: best.duration, lengthMeters: segment.lengthMeters) else { continue }
            let name: String = SharedSegments.timeRecordName(segmentID: remoteID, riderID: myID)
            if let previous = submitted[name], previous <= best.duration { continue }
            let record = CKRecord(recordType: timeType, recordID: CKRecord.ID(recordName: name))
            record["segmentID"] = remoteID as CKRecordValue
            record["seconds"] = best.duration as CKRecordValue
            record["rider"] = riderName as CKRecordValue
            record["model"] = model as CKRecordValue
            record["date"] = best.trip.startDate as CKRecordValue
            records.append(record)
            submitted[name] = best.duration
        }
        guard !records.isEmpty else { return }
        Task {
            do {
                _ = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
                UserDefaults.standard.set(submitted, forKey: submittedKey)
            } catch {
                // Réseau ou iCloud indisponible : on retentera après le prochain trajet.
            }
        }
    }

    // MARK: - Couronnes

    /// Retient si je suis le Roi de la route de ce segment.
    private static func rememberCrown(segmentID: String, rows: [Ranked]) {
        var crowns: [String: Bool] = UserDefaults.standard.dictionary(forKey: crownsKey) as? [String: Bool] ?? [:]
        crowns[segmentID] = rows.first?.isMe == true
        UserDefaults.standard.set(crowns, forKey: crownsKey)
    }

    /// À l'ouverture : prévient si quelqu'un m'a pris une couronne.
    static func checkCrowns(segments: [SegmentRecord]) async {
        let crowns: [String: Bool] = UserDefaults.standard.dictionary(forKey: crownsKey) as? [String: Bool] ?? [:]
        for segment in segments {
            guard let remoteID = segment.remoteID, crowns[remoteID] == true else { continue }
            guard let rows = try? await leaderboard(segmentID: remoteID, lengthMeters: segment.lengthMeters),
                  let king = rows.first, !king.isMe else { continue }
            let time: String = SegmentFormat.duration(king.seconds)
            let rider: String = king.rider
            let name: String = segment.name
            LocalNotifier.post(
                id: "crown-" + remoteID, title: L("👑 Couronne perdue"),
                body: L("\(rider) est le nouveau Roi de la route sur \(name) : \(time). Reprends-la !"))
        }
    }
}
