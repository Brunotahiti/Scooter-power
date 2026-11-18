import StoreKit
import UIKit

/// Demande de note sur l'App Store au meilleur moment : juste après un record
/// battu, une fois que l'utilisateur a fait quelques trajets. Au plus une fois
/// tous les 4 mois de notre côté (iOS limite aussi à 3 demandes par an).
@MainActor
enum ReviewPrompt {
    private static let lastAskKey = "reviewLastAsked"
    private static let recordsKey = "reviewRecordCount"
    private static let minimumInterval: TimeInterval = 120 * 24 * 3600

    static func recordBeaten() {
        let defaults = UserDefaults.standard
        let records: Int = defaults.integer(forKey: recordsKey) + 1
        defaults.set(records, forKey: recordsKey)
        // Dès le deuxième record : l'utilisateur connaît déjà l'app.
        guard records >= 2 else { return }
        let last: Double = defaults.double(forKey: lastAskKey)
        guard Date().timeIntervalSince1970 - last > minimumInterval else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: lastAskKey)
        // Laisse le temps à l'annonce du record de s'afficher.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
