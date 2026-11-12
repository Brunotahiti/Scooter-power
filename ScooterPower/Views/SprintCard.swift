import SwiftUI
import ScooterCore

/// Meilleurs temps d'accélération du trajet : départs arrêtés (0–30, 0–50,
/// 0–80 km/h) et reprises lancées (50–90, 50–100 km/h). Pendant une mesure,
/// le chrono tourne à gauche.
struct SprintCard: View {
    /// Un temps par plage, dans l'ordre de `SpeedInterval.all`.
    let times: [String]
    let isRunning: Bool
    /// Secondes écoulées de la mesure en cours, sans unité.
    let elapsedText: String

    var body: some View {
        HStack(spacing: 4) {
            status
            ForEach(SpeedInterval.all.indices, id: \.self) { index in
                cell(title: SpeedInterval.all[index].label, value: value(at: index))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .animation(.easeInOut(duration: 0.2), value: isRunning)
    }

    private func value(at index: Int) -> String {
        times.indices.contains(index) ? times[index] : "--"
    }

    /// Drapeau au repos, chrono orange pendant une mesure.
    private var status: some View {
        VStack(spacing: 1) {
            Image(systemName: isRunning ? "stopwatch.fill" : "flag.checkered")
                .font(.system(size: 15, weight: .medium))
            Text(isRunning ? elapsedText : "km/h")
                .font(.system(size: 11, weight: isRunning ? .bold : .regular, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(isRunning ? Theme.orange : Theme.cyan)
        .frame(width: 38)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRunning ? "Mesure en cours" : "Temps d'accélération")
        .accessibilityValue(isRunning ? elapsedText + " secondes" : "")
    }

    private func cell(title: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + " kilomètres par heure")
        .accessibilityValue(value)
    }
}

#Preview {
    SprintCard(times: ["2,1 s", "4,9 s", "9,8 s", "6,4 s", "--"], isRunning: true, elapsedText: "6,2")
        .padding()
        .background(.black)
}
