import SwiftUI

/// Tutoriel du premier lancement : cinq pages à faire défiler.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let icon: String
        let color: Color
        let title: String
        let text: String
    }

    private var pages: [Page] {
        [
            Page(icon: "gauge.with.dots.needle.67percent", color: Theme.cyan,
                 title: L("Votre tableau de bord"),
                 text: L("Fixez l'iPhone au guidon et touchez Démarrer. Vitesse, inclinaison, accélération et chronos s'affichent en direct.")),
            Page(icon: "trophy.fill", color: Theme.orange,
                 title: L("Battez vos records"),
                 text: L("Chaque trajet est enregistré. Revivez-le vu du ciel, sur photo satellite, et partagez-le en vidéo.")),
            Page(icon: "person.3.fill", color: Theme.cyan,
                 title: L("Roulez en groupe"),
                 text: L("Jusqu'à 5 pilotes sur la même carte : un QR code suffit pour rejoindre la balade.")),
            Page(icon: "cross.case.fill", color: Theme.red,
                 title: L("Roulez protégé"),
                 text: L("En cas de chute, l'app sonne et propose de prévenir vos proches avec votre position. Ajoutez vos contacts dans les Réglages.")),
            Page(icon: "wrench.and.screwdriver.fill", color: Theme.orange,
                 title: L("Garage et départ automatique"),
                 text: L("Suivez l'entretien de votre scooter. Démarrez avec Siri, le widget ou la connexion de votre casque.")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(L("Passer"), action: onFinish)
                    .foregroundStyle(Theme.textSecondary)
                    .padding()
            }
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 24) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(item.color.opacity(0.15))
                                .frame(width: 150, height: 150)
                            Image(systemName: item.icon)
                                .font(.system(size: 64, weight: .bold))
                                .foregroundStyle(item.color)
                        }
                        Text(item.title)
                            .font(.title.weight(.heavy))
                            .multilineTextAlignment(.center)
                        Text(item.text)
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? L("Suivant") : L("C'est parti"))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.cyan, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.textPrimary)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
