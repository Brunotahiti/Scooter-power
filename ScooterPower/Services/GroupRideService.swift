import CloudKit
import Foundation
import Observation
import ScooterCore

/// Balade de groupe en direct, par la base publique iCloud de l'app.
///
/// Deux types d'enregistrements :
/// - `Ride` (nom = identifiant de la balade) : la liste ordonnée des pilotes ;
/// - `RideRider` (nom = balade-pilote) : la dernière position de chacun.
/// Chaque téléphone écrit sa position et relit celles des autres toutes les
/// quelques secondes. Aucune requête n'est faite : tout est lu par nom, ce qui
/// évite d'avoir à créer des index dans la console CloudKit.
/// L'identifiant de pilote est tiré au hasard et n'est lié à aucun compte.
@MainActor
@Observable
final class GroupRideService {
    static let shared = GroupRideService()

    static let containerID = "iCloud.com.brunotahiti.ScooterPower"
    static let syncInterval: TimeInterval = 3

    enum Phase: Equatable {
        case idle
        case connecting
        case active
        case failed(String)
    }

    /// Un pilote de la balade, tel qu'affiché.
    struct Rider: Identifiable, Equatable {
        let id: String
        var colorIndex: Int
        var position: RiderPosition?
        var trail: RiderTrail
        var isMe: Bool
    }

    private(set) var phase: Phase = .idle
    private(set) var link: RideLink?
    private(set) var riders: [Rider] = []

    /// Identifiant de ce téléphone dans les balades, tiré une fois pour toutes.
    let myID: String = {
        let key = "groupRideRiderID"
        if let stored = UserDefaults.standard.string(forKey: key) { return stored }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }()

    /// Fournit la position actuelle de ce téléphone, `nil` s'il n'y en a pas.
    var positionProvider: (() -> RiderPosition?)?

    private var timer: Timer?
    private var trails: [String: RiderTrail] = [:]
    private var syncing = false

    private var database: CKDatabase {
        CKContainer(identifier: Self.containerID).publicCloudDatabase
    }

    var isInRide: Bool { link != nil }

    // MARK: - Créer, rejoindre, quitter

    func create() {
        Task { await start(link: RideLink.random(), creating: true) }
    }

    func join(_ link: RideLink) {
        guard link != self.link else { return }
        Task {
            if self.link != nil { await leaveNow() }
            await start(link: link, creating: false)
        }
    }

    func leave() {
        Task { await leaveNow() }
    }

    private func start(link: RideLink, creating: Bool) async {
        phase = .connecting
        do {
            let status = try await CKContainer(identifier: Self.containerID).accountStatus()
            guard status == .available else {
                phase = .failed(L("Connectez-vous à iCloud dans les Réglages de l'iPhone pour rouler en groupe."))
                return
            }
            try await updateRoster(rideID: link.rideID, creating: creating) { roster in
                try roster.join(self.myID)
            }
            self.link = link
            trails = [:]
            phase = .active
            await sync()
            startTimer()
        } catch GroupRoster.JoinError.full {
            phase = .failed(L("Cette balade est complète : 5 pilotes au maximum."))
        } catch RideError.notFound {
            phase = .failed(L("Balade introuvable. Demandez un nouveau QR code."))
        } catch {
            phase = .failed(L("Connexion à iCloud impossible. Vérifiez le réseau et réessayez."))
        }
    }

    private func leaveNow() async {
        timer?.invalidate()
        timer = nil
        guard let link else { phase = .idle; return }
        let rideID = link.rideID
        self.link = nil
        riders = []
        trails = [:]
        phase = .idle
        try? await updateRoster(rideID: rideID, creating: false) { roster in
            roster.leave(self.myID)
        }
        _ = try? await database.deleteRecord(withID: riderRecordID(rideID: rideID, riderID: myID))
    }

    // MARK: - Synchronisation

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.syncInterval, repeats: true) { _ in
            Task { @MainActor in await GroupRideService.shared.sync() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Envoie ma position, puis relit la liste des pilotes et leurs positions.
    func sync() async {
        guard let link, !syncing else { return }
        syncing = true
        defer { syncing = false }
        if let mine = positionProvider?() {
            let record = CKRecord(recordType: "RideRider", recordID: riderRecordID(rideID: link.rideID, riderID: myID))
            Self.fill(record, with: mine)
            _ = try? await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        }
        guard let rideRecord = try? await database.record(for: CKRecord.ID(recordName: link.rideID)) else { return }
        let roster = GroupRoster(members: rideRecord["members"] as? [String] ?? [])
        let ids: [CKRecord.ID] = roster.members.map { riderRecordID(rideID: link.rideID, riderID: $0) }
        let results = (try? await database.records(for: ids)) ?? [:]
        var updated: [Rider] = []
        for (index, member) in roster.members.enumerated() {
            let id = riderRecordID(rideID: link.rideID, riderID: member)
            var position: RiderPosition?
            if case .success(let record)? = results[id] {
                position = Self.position(from: record, riderID: member)
            }
            var trail: RiderTrail = trails[member] ?? RiderTrail()
            if let position { trail.add(position.coordinate) }
            trails[member] = trail
            updated.append(Rider(id: member, colorIndex: index, position: position, trail: trail, isMe: member == myID))
        }
        // Ma propre position est affichée sans attendre l'aller-retour iCloud.
        if let mine = positionProvider?(), let index = updated.firstIndex(where: { $0.isMe }) {
            updated[index].position = mine
        }
        riders = updated
    }

    // MARK: - Enregistrements

    private enum RideError: Error {
        case notFound
    }

    private func riderRecordID(rideID: String, riderID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: rideID + "-" + riderID)
    }

    /// Lit, modifie et réécrit la liste des pilotes ; recommence si un autre
    /// pilote l'a changée entre-temps.
    private func updateRoster(rideID: String, creating: Bool, change: (inout GroupRoster) throws -> Void) async throws {
        let id = CKRecord.ID(recordName: rideID)
        for _ in 0..<4 {
            let record: CKRecord
            do {
                record = try await database.record(for: id)
            } catch let error as CKError where error.code == .unknownItem {
                guard creating else { throw RideError.notFound }
                record = CKRecord(recordType: "Ride", recordID: id)
            }
            var roster = GroupRoster(members: record["members"] as? [String] ?? [])
            try change(&roster)
            record["members"] = roster.members as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue
            do {
                _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
                return
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            }
        }
        throw RideError.notFound
    }

    private static func fill(_ record: CKRecord, with position: RiderPosition) {
        record["name"] = position.name as CKRecordValue
        record["latitude"] = position.coordinate.latitude as CKRecordValue
        record["longitude"] = position.coordinate.longitude as CKRecordValue
        record["speed"] = position.speedKmh as CKRecordValue
        record["heading"] = position.heading as CKRecordValue
        record["lean"] = position.leanDegrees as CKRecordValue
        record["acceleration"] = position.acceleration as CKRecordValue
        record["updatedAt"] = position.updatedAt as CKRecordValue
    }

    private static func position(from record: CKRecord, riderID: String) -> RiderPosition? {
        guard let latitude = record["latitude"] as? Double, let longitude = record["longitude"] as? Double,
              latitude.isFinite, longitude.isFinite
        else { return nil }
        return RiderPosition(
            riderID: riderID,
            name: String((record["name"] as? String ?? "").prefix(SharedTrip.maxNameLength)),
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            speedKmh: record["speed"] as? Double ?? 0,
            heading: record["heading"] as? Double ?? 0,
            leanDegrees: record["lean"] as? Double ?? 0,
            acceleration: record["acceleration"] as? Double ?? 0,
            updatedAt: record["updatedAt"] as? Date ?? record.modificationDate ?? .distantPast)
    }
}
