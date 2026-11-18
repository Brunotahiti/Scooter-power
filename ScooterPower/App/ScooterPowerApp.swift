import ScooterCore
import SwiftData
import SwiftUI

@main
struct ScooterPowerApp: App {
    /// Vrai une fois l'avertissement de sécurité lu au premier lancement.
    @AppStorage("safetyNoticeAccepted") private var safetyNoticeAccepted = false
    /// Vrai une fois l'animation d'ouverture jouée (à chaque lancement de l'app).
    @State private var introDone = false

    /// Historique stocké uniquement sur l'iPhone. Sans `cloudKitDatabase: .none`,
    /// SwiftData tenterait de le synchroniser avec iCloud dès que la capacité
    /// iCloud est activée (elle sert seulement à la balade de groupe).
    /// Même fichier qu'avant (`default.store`) : les trajets existants sont conservés.
    private let container: ModelContainer = {
        let schema = Schema([
            TripRecord.self, RivalRecord.self, FriendTrip.self, GroupRideRecord.self,
            Scooter.self, MaintenanceTask.self, FuelEntry.self,
        ])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible d'ouvrir l'historique : \(error)")
        }
    }()

    init() {
        // Langue choisie dans les réglages (anglais par défaut) et séparateur décimal assorti.
        AppLanguage.apply(AppLanguage.stored)
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
            // Textes SwiftUI, graphiques, sélecteurs et dates dans la langue de l'app.
            .modifier(AppLanguageEnvironment())
        }
        .modelContainer(container)
    }
}

/// Pose la langue choisie dans l'environnement ; suit ses changements en direct.
private struct AppLanguageEnvironment: ViewModifier {
    private let settings = AppSettings.shared

    func body(content: Content) -> some View {
        content.environment(\.locale, settings.language.locale)
    }
}
