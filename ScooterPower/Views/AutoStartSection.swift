import AppIntents
import SwiftUI

/// Réglages : démarrage automatique avec Siri, Raccourcis, le bouton Action,
/// la connexion du casque Bluetooth ou un tag NFC posé sur le scooter.
struct AutoStartSection: View {
    private let auto = AutoTripService.shared

    private var enabled: Binding<Bool> {
        Binding(get: { auto.isEnabled }, set: { auto.setEnabled($0) })
    }

    private var background: Binding<Bool> {
        Binding(get: { auto.backgroundEnabled }, set: { auto.setBackgroundEnabled($0) })
    }

    var body: some View {
        Section {
            Toggle(L("Démarrer et arrêter automatiquement"), isOn: enabled)
                .tint(Theme.cyan)
            if auto.isEnabled {
                Toggle(L("Me prévenir aussi app fermée"), isOn: background)
                    .tint(Theme.cyan)
            }
        } footer: {
            Text(auto.isEnabled
                 ? L("App ouverte : l'enregistrement démarre dès 15 km/h pendant 15 s, et le trajet se termine après 3 min à l'arrêt. App fermée : une notification vous propose d'enregistrer quand l'iPhone détecte que vous roulez (position « Toujours » demandée).")
                 : L("L'app démarre l'enregistrement quand vous partez et le termine quand vous vous arrêtez."))
        }
        Section {
            VStack(alignment: .leading, spacing: 10) {
                step("mic.fill", L("Dites « Dis Siri, démarre Scooter Power »."))
                step("headphones", L("Raccourcis > Automatisation > Bluetooth : choisissez votre casque, puis l'action « Démarrer un trajet ». À la déconnexion : « Terminer le trajet »."))
                step("wave.3.right", L("Raccourcis > Automatisation > NFC : touchez un tag collé sur le scooter pour démarrer."))
                step("button.horizontal.top.press", L("Bouton Action de l'iPhone : Réglages > Bouton Action > Raccourci > Scooter Power."))
            }
            .padding(.vertical, 4)
            ShortcutsLink()
                .shortcutsLinkStyle(.automaticOutline)
                .frame(maxWidth: .infinity)
        } header: {
            Text(L("Démarrage automatique"))
        }
    }

    private func step(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.cyan)
                .frame(width: 22)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
