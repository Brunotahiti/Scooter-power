import CloudKit
import Foundation
import ScooterCore

/// Une ligne de classement.
struct LeaderboardRow: Identifiable, Equatable {
    let id: String
    let rider: String
    let model: String
    let seconds: TimeInterval
    let date: Date
    let isMe: Bool
}

/// Classements en ligne, dans la base publique iCloud de l'app : un temps par
/// pilote, modèle de scooter et plage de vitesse. Seuls le prénom (ou pseudo),
/// le modèle et les chronos sont publiés, et seulement si le pilote l'a accepté.
@MainActor
enum LeaderboardService {
    private static let recordType = "LeaderboardEntry"
    private static let submittedKey = "leaderboardSubmitted"

    private static var database: CKDatabase {
        CKContainer(identifier: GroupRideService.containerID).publicCloudDatabase
    }

    private static var myID: String { GroupRideService.shared.myID }

    /// Publie les meilleurs temps de ces trajets, s'ils améliorent ceux déjà publiés.
    static func submit(trips: [TripRecord], scooter: Scooter) {
        let settings = AppSettings.shared
        let modelKey: String = Leaderboard.modelKey(scooter.model)
        guard settings.leaderboardEnabled, !modelKey.isEmpty else { return }
        var submitted: [String: Double] = UserDefaults.standard.dictionary(forKey: submittedKey) as? [String: Double] ?? [:]
        var records: [CKRecord] = []
        for interval in SpeedInterval.all {
            let candidates: [(seconds: TimeInterval, date: Date)] = trips.compactMap { trip in
                guard let time = trip.summary.best(interval), Leaderboard.isPublishable(time, for: interval) else { return nil }
                return (time, trip.startDate)
            }
            guard let best = candidates.min(by: { $0.seconds < $1.seconds }) else { continue }
            let seconds: TimeInterval = best.seconds
            let intervalID: String = Leaderboard.intervalID(interval)
            let name: String = Leaderboard.recordName(riderID: myID, modelKey: modelKey, intervalID: intervalID)
            if let previous = submitted[name], previous <= seconds { continue }
            let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: name))
            record["model"] = scooter.model as CKRecordValue
            record["modelKey"] = modelKey as CKRecordValue
            record["interval"] = intervalID as CKRecordValue
            record["seconds"] = seconds as CKRecordValue
            record["rider"] = riderName as CKRecordValue
            record["date"] = best.date as CKRecordValue
            records.append(record)
            submitted[name] = seconds
        }
        guard !records.isEmpty else { return }
        Task {
            do {
                // Remplace l'ancien temps de ce pilote (même nom d'enregistrement).
                _ = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
                UserDefaults.standard.set(submitted, forKey: submittedKey)
            } catch {
                // Réseau ou iCloud indisponible : on retentera au prochain record.
            }
        }
    }

    /// Les 50 meilleurs temps d'une plage, pour un modèle ou tous modèles confondus.
    static func top(interval: SpeedInterval, modelKey: String?) async throws -> [LeaderboardRow] {
        let intervalID: String = Leaderboard.intervalID(interval)
        let predicate: NSPredicate
        if let modelKey {
            predicate = NSPredicate(format: "interval == %@ AND modelKey == %@", intervalID, modelKey)
        } else {
            predicate = NSPredicate(format: "interval == %@", intervalID)
        }
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "seconds", ascending: true)]
        let (results, _) = try await database.records(matching: query, resultsLimit: 50)
        let prefix: String = "lb_" + myID + "_"
        return results.compactMap { entry -> LeaderboardRow? in
            let id: CKRecord.ID = entry.0
            guard let record = try? entry.1.get(), let seconds = record["seconds"] as? Double else { return nil }
            return LeaderboardRow(
                id: id.recordName,
                rider: (record["rider"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? L("Pilote"),
                model: record["model"] as? String ?? "",
                seconds: seconds,
                date: record["date"] as? Date ?? Date(),
                isMe: id.recordName.hasPrefix(prefix))
        }
        .sorted { $0.seconds < $1.seconds }
    }

    /// Retire tous mes temps des classements.
    static func removeMine() async {
        let submitted: [String: Double] = UserDefaults.standard.dictionary(forKey: submittedKey) as? [String: Double] ?? [:]
        let ids: [CKRecord.ID] = submitted.keys.map { CKRecord.ID(recordName: $0) }
        guard !ids.isEmpty else { return }
        _ = try? await database.modifyRecords(saving: [], deleting: ids)
        UserDefaults.standard.removeObject(forKey: submittedKey)
    }

    private static var riderName: String {
        let name: String = AppSettings.shared.riderName
        return name.isEmpty ? L("Pilote") : name
    }
}
