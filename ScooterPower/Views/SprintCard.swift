import SwiftUI

/// Meilleurs temps départ arrêté du trajet, et chrono de la mesure en cours.
struct SprintCard: View {
    let best50Text: String
    let best80Text: String
    let isRunning: Bool
    let elapsedText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.cyan)
            cell(title: "0–50 km/h", value: best50Text)
            divider
            cell(title: "0–80 km/h", value: best80Text)
            if isRunning {
                divider
                chrono
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .animation(.easeInOut(duration: 0.2), value: isRunning)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.cardBorder)
            .frame(width: 1, height: 24)
    }

    private var chrono: some View {
        HStack(spacing: 4) {
            Image(systemName: "stopwatch.fill")
            Text(elapsedText)
                .monospacedDigit()
        }
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(Theme.orange)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mesure en cours")
        .accessibilityValue(elapsedText)
    }

    private func cell(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

#Preview {
    SprintCard(best50Text: "4,9 s", best80Text: "--", isRunning: true, elapsedText: "6,2 s")
        .padding()
        .background(.black)
}
