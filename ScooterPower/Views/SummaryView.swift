import SwiftUI
import ScooterCore

struct SummaryView: View {
    let summary: TripSummary
    let route: [Coordinate]
    let date: Date?
    let onDone: () -> Void

    @State private var share = ShareState()

    private var shareTitle: String {
        (date ?? Date()).formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Résumé du trajet")
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                ShareMenu(summary: summary, route: route, title: shareTitle, date: date) { url in
                    share.receive(url)
                }
            }
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
        .sharePresentation($share)
        .preferredColorScheme(.dark)
    }
}
