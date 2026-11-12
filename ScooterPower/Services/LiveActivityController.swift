import ActivityKit
import Foundation
import ScooterCore

/// Affiche le trajet en cours sur l'écran verrouillé et dans la Dynamic Island.
/// Sans effet si l'utilisateur a désactivé les activités en direct.
@MainActor
final class LiveActivityController {
    typealias State = TripActivityAttributes.ContentState

    /// Intervalle minimal entre deux mises à jour, en secondes.
    private static let minimumInterval: TimeInterval = 1
    /// Sans mise à jour pendant ce délai, le système marque l'activité comme périmée (s).
    private static let staleAfter: TimeInterval = 30

    private static func content(_ state: State) -> ActivityContent<State> {
        ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleAfter))
    }

    private var activity: Activity<TripActivityAttributes>?
    private var lastState: State?
    private var lastUpdate = Date.distantPast

    func start(startDate: Date, state: State) {
        endOrphans()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = Self.content(state)
        do {
            activity = try Activity.request(
                attributes: TripActivityAttributes(startDate: startDate),
                content: content,
                pushType: nil)
            lastState = state
            lastUpdate = Date()
        } catch {
            // Activités indisponibles : le trajet continue sans elles.
            activity = nil
        }
    }

    func update(_ state: State) {
        guard let activity, state != lastState else { return }
        let now = Date()
        // Un changement de pause passe toujours, sans attendre l'intervalle.
        let pauseChanged: Bool = state.isPaused != lastState?.isPaused
        guard pauseChanged || now.timeIntervalSince(lastUpdate) >= Self.minimumInterval else { return }
        lastState = state
        lastUpdate = now
        let content = Self.content(state)
        Task {
            await activity.update(content)
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Termine les activités laissées par une session précédente de l'app
    /// (app tuée ou plantée pendant un trajet).
    func endOrphans() {
        for orphan in Activity<TripActivityAttributes>.activities {
            Task {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
