import SwiftUI
import ScooterCore

struct SummaryView: View {
    let summary: TripSummary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Résumé du trajet")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 16)

            ScrollView {
                TripFigures(summary: summary)
            }

            Button(action: onDone) {
                Text("Nouveau trajet")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
