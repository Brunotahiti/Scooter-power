import Foundation
import Observation
import ScooterCore

/// Journal des alertes de chute, gardé sur l'iPhone : il sert à repérer les
/// fausses alertes (support qui lâche, grosse bosse) et à régler les seuils.
struct CrashLogEntry: Codable, Identifiable, Equatable {
    enum Outcome: String, Codable {
        /// Pas encore de réponse.
        case pending
        /// « Je vais bien » : probablement une fausse alerte.
        case fine
        /// Contacts prévenus ou appel d'urgence.
        case alerted
        /// Mode réglage : alerte notée sans sonner.
        case silent
    }

    let id: UUID
    let date: Date
    let trigger: CrashDetector.Trigger?
    var outcome: Outcome
    /// Secondes avant la réponse du pilote.
    var responseSeconds: Double?
}

@MainActor
@Observable
final class CrashLog {
    static let shared = CrashLog()
    private static let key = "crashLog"
    private static let maxEntries = 50

    private(set) var entries: [CrashLogEntry]

    private init() {
        let data: Data? = UserDefaults.standard.data(forKey: Self.key)
        entries = data.flatMap { try? JSONDecoder().decode([CrashLogEntry].self, from: $0) } ?? []
    }

    func add(id: UUID, date: Date, trigger: CrashDetector.Trigger?, outcome: CrashLogEntry.Outcome) {
        entries.insert(CrashLogEntry(id: id, date: date, trigger: trigger, outcome: outcome), at: 0)
        if entries.count > Self.maxEntries { entries.removeLast(entries.count - Self.maxEntries) }
        save()
    }

    /// Réponse du pilote à l'alerte ; la première compte.
    func resolve(id: UUID, outcome: CrashLogEntry.Outcome) {
        guard let index = entries.firstIndex(where: { $0.id == id }), entries[index].outcome == .pending else { return }
        entries[index].outcome = outcome
        entries[index].responseSeconds = Date().timeIntervalSince(entries[index].date)
        save()
    }

    func clear() {
        entries = []
        save()
    }

    /// Texte à envoyer pour le réglage des seuils (aucune position).
    var report: String {
        var lines: [String] = ["Scooter Power — crash log", ""]
        let formatter = ISO8601DateFormatter()
        for entry in entries {
            var parts: [String] = [formatter.string(from: entry.date), entry.outcome.rawValue]
            if let trigger = entry.trigger {
                parts.append(trigger.reason.rawValue)
                parts.append(String(format: "peak %.1fg", trigger.peakG))
                parts.append(String(format: "tilt %.0f°", trigger.tiltDegrees))
                parts.append(String(format: "speed %.0f km/h", trigger.speedBeforeKmh))
            }
            if let seconds = entry.responseSeconds { parts.append(String(format: "answered %.0fs", seconds)) }
            lines.append(parts.joined(separator: " · "))
        }
        return lines.joined(separator: "\n")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
