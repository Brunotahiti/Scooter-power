import ScooterCore
import SwiftData
import SwiftUI

@main
struct ScooterPowerApp: App {
    /// Vrai une fois l'avertissement de sécurité lu au premier lancement.
    @AppStorage("safetyNoticeAccepted") private var safetyNoticeAccepted = false
    /// Vrai une fois l'animation d'ouverture jouée (à chaque lancement de l'app).
    @State private var introDone = false

    init() {
        // Virgule ou point décimal, selon la langue et la région de l'appareil.
        Formatters.decimalSeparator = Locale.current.decimalSeparator ?? ","
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if safetyNoticeAccepted {
                    TripScreen()
                } else {
                    SafetyNoticeView(onAccept: { safetyNoticeAccepted = true })
                }
                if !introDone {
                    IntroView(onFinish: {
                        withAnimation(.easeOut(duration: 0.5)) { introDone = true }
                    })
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
        .modelContainer(for: [TripRecord.self, RivalRecord.self])
    }
}
