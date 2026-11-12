import SwiftUI

/// Avertissement de sécurité, affiché une seule fois au premier lancement.
struct SafetyNoticeView: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.orange)

            Text("Roulez en sécurité")
                .font(.system(size: 28, weight: .bold))

            VStack(alignment: .leading, spacing: 14) {
                point("hand.raised.fill", "Ne manipulez jamais l'application en roulant. Démarrez et terminez le trajet à l'arrêt.")
                point("iphone.gen3", "Fixez solidement le téléphone au guidon avant de partir.")
                point("eye.fill", "Gardez les yeux sur la route. Les mesures sont indicatives et ne remplacent pas le compteur du véhicule.")
                point("flag.checkered", "Respectez le code de la route. Les mesures d'accélération sont réservées aux lieux où elles sont autorisées et sans danger.")
            }

            Spacer(minLength: 0)

            Button(action: onAccept) {
                Text("J'ai compris")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func point(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.cyan)
                .frame(width: 26)
            Text(text)
                .font(.system(size: 16))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SafetyNoticeView(onAccept: {})
}
