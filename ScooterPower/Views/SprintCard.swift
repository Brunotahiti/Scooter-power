import SwiftUI
import ScooterCore

/// Temps d'accélération : départs arrêtés (0–30, 0–50, 0–80 km/h) et reprises
/// lancées (50–90, 50–100 km/h). Pour chaque plage, le meilleur temps du
/// trajet et, dessous, le record tous trajets confondus. Pendant une mesure,
/// le chrono tourne à gauche.
struct SprintCard: View {
    /// Meilleur temps du trajet par plage, dans l'ordre de `SpeedInterval.all`.
    let times: [String]
    /// Record tous trajets confondus par plage, dans le même ordre.
    let records: [String]
    /// Indices des plages dont le record a été battu pendant ce trajet.
    let beaten: Set<Int>
    let isRunning: Bool
    /// Secondes écoulées de la mesure en cours, sans unité.
    let elapsedText: String

    var body: some View {
        HStack(spacing: 4) {
            status
            ForEach(SpeedInterval.all.indices, id: \.self) { index in
                cell(index)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .animation(.easeInOut(duration: 0.2), value: isRunning)
    }

    private func text(_ list: [String], at index: Int) -> String {
        list.indices.contains(index) ? list[index] : "--"
    }

    /// Drapeau au repos, chrono orange pendant une mesure.
    private var status: some View {
        VStack(spacing: 1) {
            Image(systemName: isRunning ? "stopwatch.fill" : "flag.checkered")
                .font(.system(size: 15, weight: .medium))
            Text(verbatim: isRunning ? elapsedText : "km/h")
                .font(.system(size: 11, weight: isRunning ? .bold : .regular, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(isRunning ? Theme.orange : Theme.cyan)
        .frame(width: 38)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRunning ? L("Mesure en cours") : L("Temps d'accélération"))
        .accessibilityValue(isRunning ? L("\(elapsedText) secondes") : "")
    }

    private func cell(_ index: Int) -> some View {
        let title: String = SpeedInterval.all[index].label
        let value: String = text(times, at: index)
        let record: String = text(records, at: index)
        let isBeaten: Bool = beaten.contains(index)
        return VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isBeaten ? Theme.orange : Theme.textPrimary)
            recordLine(record, isBeaten: isBeaten)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + " km/h")
        .accessibilityValue(
            isBeaten ? L("\(value), record \(record), battu pendant ce trajet") : L("\(value), record \(record)"))
    }

    private func recordLine(_ record: String, isBeaten: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 7))
            Text(record)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(isBeaten ? Theme.orange : Theme.cyan)
    }
}

#Preview {
    SprintCard(
        times: ["2,1 s", "4,2 s", "9,8 s", "6,4 s", "--"],
        records: ["2,0 s", "4,2 s", "9,1 s", "6,0 s", "8,8 s"],
        beaten: [1],
        isRunning: true,
        elapsedText: "6,2")
        .padding()
        .background(.black)
}
