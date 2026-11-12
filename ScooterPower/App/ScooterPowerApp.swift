import ScooterCore
import SwiftData
import SwiftUI

@main
struct ScooterPowerApp: App {
    /// Vrai une fois l'avertissement de sécurité lu au premier lancement.
    @AppStorage("safetyNoticeAccepted") private var safetyNoticeAccepted = false

    init() {
        // Virgule ou point décimal, selon la langue et la région de l'appareil.
        Formatters.decimalSeparator = Locale.current.decimalSeparator ?? ","
    }

    var body: some Scene {
        WindowGroup {
            if safetyNoticeAccepted {
                TripScreen()
            } else {
                SafetyNoticeView(onAccept: { safetyNoticeAccepted = true })
            }
        }
        .modelContainer(for: TripRecord.self)
    }
}
