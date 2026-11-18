import AppIntents
import SwiftUI

/// Réglages : démarrage automatique avec Siri, Raccourcis, le bouton Action,
/// la connexion du casque Bluetooth ou un tag NFC posé sur le scooter.
struct AutoStartSection: View {
    var body: some View {
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
