import CloudKit
import Foundation
import Observation
import ScooterCore

/// Position en direct pour les proches : pendant un trajet, l'app publie
/// toutes les 10 s la position, la vitesse et le tracé dans la base publique
/// iCloud, sous un identifiant aléatoire. La page web du lien les affiche.
/// Le lien reste le même d'un trajet à l'autre (on le donne une fois à ses
/// proches) ; « Nouveau lien » le remplace et efface l'ancien.
@MainActor
@Observable
final class LiveShareService {
    static let shared = LiveShareService()
    private static let recordType = "LiveShare"
    private static let idKey = "liveShareID"
    private static let enabledKey = "liveShareEnabled"
    static let interval: TimeInterval = 10

    /// Partage activé : chaque trajet est suivi en direct.
    private(set) var isEnabled: Bool = UserDefaults.standard.bool(forKey: LiveShareService.enabledKey)
    /// Vrai pendant un trajet suivi en direct.
    private(set) var isLive = false
    private(set) var lastSent: Date?
    private(set) var failed = false

    /// Fournit l'état du trajet en cours (position, tracé…), ou `nil` à l'arrêt.
    var snapshotProvider: (() -> Snapshot?)?

    struct Snapshot {
        var position: RiderPosition
        var route: [Coordinate]
        var state: LiveShare.State
    }

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var sending = false

    private var database: CKDatabase {
        CKContainer(identifier: GroupRideService.containerID).publicCloudDatabase
    }

    /// Identifiant du lien, créé une fois pour toutes.
    var shareID: String {
        if let stored = UserDefaults.standard.string(forKey: Self.idKey) { return stored }
        let fresh: String = LiveShare.newID()
        UserDefaults.standard.set(fresh, forKey: Self.idKey)
        return fresh
    }

    var link: URL? { LiveShare.link(id: shareID) }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
        if !value {
            stop(final: nil)
            Task { await deleteRecord(id: shareID) }
        }
    }

    /// Remplace le lien : l'ancien ne montre plus rien.
    func renewLink() {
        let old: String = shareID
        UserDefaults.standard.set(LiveShare.newID(), forKey: Self.idKey)
        Task { await deleteRecord(id: old) }
        if isLive { send() }
    }

    // MARK: - Trajet

    /// Début d'un trajet (ou reprise) : envoi immédiat puis toutes les 10 s.
    func tripStarted() {
        guard isEnabled, !isLive else { return }
        isLive = true
        send()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.send() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Fin du trajet : dernier envoi avec l'état « arrivé ».
    func tripFinished() {
        stop(final: .arrived)
    }

    /// Alerte de chute : envoyée tout de suite, la page l'affiche en rouge.
    func crashAlert() {
        guard isLive else { return }
        send(override: .alert)
    }

    private func stop(final state: LiveShare.State?) {
        timer?.invalidate()
        timer = nil
        if let state, isLive { send(override: state) }
        isLive = false
    }

    private func send(override state: LiveShare.State? = nil) {
        guard isEnabled, !sending, let snapshot = snapshotProvider?() else { return }
        sending = true
        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: shareID))
        let position: RiderPosition = snapshot.position
        let name: String = AppSettings.shared.riderName
        record["name"] = (name.isEmpty ? L("Pilote") : name) as CKRecordValue
        record["latitude"] = position.coordinate.latitude as CKRecordValue
        record["longitude"] = position.coordinate.longitude as CKRecordValue
        record["speed"] = max(0, position.speedKmh) as CKRecordValue
        record["heading"] = position.heading as CKRecordValue
        record["state"] = (state ?? snapshot.state).rawValue as CKRecordValue
        record["trail"] = LiveShare.encodeTrail(snapshot.route) as CKRecordValue
        record["units"] = (AppSettings.shared.units == .metric ? "kmh" : "mph") as CKRecordValue
        record["language"] = AppSettings.shared.language.rawValue as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        Task {
            defer { sending = false }
            do {
                _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                lastSent = Date()
                failed = false
            } catch {
                failed = true
            }
        }
    }

    private func deleteRecord(id: String) async {
        _ = try? await database.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: id)])
    }
}
