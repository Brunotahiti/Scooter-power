import AppIntents
import Foundation
import Observation
import ScooterCore

/// Commande reçue de Siri, de Raccourcis, du bouton Action ou du widget.
/// L'écran du trajet l'exécute dès qu'il est affiché.
enum TripCommand: Equatable {
    case start, pause, resume, finish
}

@MainActor
@Observable
final class TripCommands {
    static let shared = TripCommands()
    private(set) var pending: TripCommand?
    /// Course contre un trajet passé, demandée depuis l'historique.
    private(set) var pendingGhost: GhostRequest?

    struct GhostRequest: Equatable {
        let id = UUID()
        let race: GhostRace
        let title: String

        static func == (lhs: GhostRequest, rhs: GhostRequest) -> Bool { lhs.id == rhs.id }
    }

    func request(_ command: TripCommand) {
        pending = command
    }

    func raceGhost(_ race: GhostRace, title: String) {
        pendingGhost = GhostRequest(race: race, title: title)
    }

    func takeGhost() -> GhostRequest? {
        defer { pendingGhost = nil }
        return pendingGhost
    }

    /// Rend la commande en attente et l'efface.
    func take() -> TripCommand? {
        defer { pending = nil }
        return pending
    }
}

struct StartTripIntent: AppIntent {
    static var title = LocalizedStringResource("Démarrer un trajet")
    static var description = IntentDescription(LocalizedStringResource("Ouvre Scooter Power et lance l'enregistrement du trajet."))
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        TripCommands.shared.request(.start)
        return .result()
    }
}

struct FinishTripIntent: AppIntent {
    static var title = LocalizedStringResource("Terminer le trajet")
    static var description = IntentDescription(LocalizedStringResource("Termine et enregistre le trajet en cours."))
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        TripCommands.shared.request(.finish)
        return .result()
    }
}

struct PauseTripIntent: AppIntent {
    static var title = LocalizedStringResource("Mettre le trajet en pause")
    static var description = IntentDescription(LocalizedStringResource("Met en pause le trajet en cours."))
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        TripCommands.shared.request(.pause)
        return .result()
    }
}

struct ResumeTripIntent: AppIntent {
    static var title = LocalizedStringResource("Reprendre le trajet")
    static var description = IntentDescription(LocalizedStringResource("Reprend le trajet mis en pause."))
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        TripCommands.shared.request(.resume)
        return .result()
    }
}

/// Phrases Siri et actions proposées dans Raccourcis et pour le bouton Action.
/// Les phrases françaises sont dans AppShortcuts.xcstrings.
struct ScooterPowerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTripIntent(),
            phrases: [
                "Start a trip in \(.applicationName)",
                "Start \(.applicationName)",
                "Start recording in \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("Démarrer un trajet"),
            systemImageName: "play.fill")
        AppShortcut(
            intent: FinishTripIntent(),
            phrases: [
                "End my trip in \(.applicationName)",
                "Stop \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("Terminer le trajet"),
            systemImageName: "stop.fill")
        AppShortcut(
            intent: PauseTripIntent(),
            phrases: ["Pause \(.applicationName)", "Pause my trip in \(.applicationName)"],
            shortTitle: LocalizedStringResource("Pause"),
            systemImageName: "pause.fill")
        AppShortcut(
            intent: ResumeTripIntent(),
            phrases: ["Resume \(.applicationName)", "Resume my trip in \(.applicationName)"],
            shortTitle: LocalizedStringResource("Reprendre"),
            systemImageName: "play.circle.fill")
    }
}
