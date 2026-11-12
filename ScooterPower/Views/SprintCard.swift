import SwiftUI
import ScooterCore

/// Temps d'accélération : départs arrêtés (0–30, 0–50, 0–80 km/h) et reprises
/// lancées (50–90, 50–100 km/h). Pour chaque plage : le meilleur temps du
/// trajet, une barre qui se remplit à l'approche du record, et le record
/// tous trajets confondus. Pendant une mesure, le chrono tourne à gauche.
struct SprintCard: View {
    /// Meilleur temps du trajet par plage, dans l'ordre de `SpeedInterval.all`.
    let times: [String]
    /// Record tous trajets confondus par plage, dans le même ordre.
    let records: [String]
    /// De 0 à 1 par plage : 1 quand le temps du trajet égale ou bat le record.
    let progress: [Double]
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
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .animation(.easeInOut(duration: 0.2), value: isRunning)
    }

    private func text(_ list: [String], at index: Int) -> String {
        list.indices.contains(index) ? list[index] : "--"
    }

    /// Compteur au repos, chrono orange pendant une mesure.
    private var status: some View {
        VStack(spacing: 1) {
            Image(systemName: isRunning ? "stopwatch.fill" : "gauge.with.needle")
                .font(.system(size: 18, weight: .medium))
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
        let fraction: Double = progress.indices.contains(index) ? min(1, max(0, progress[index])) : 0
        return VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isBeaten ? Theme.orange : Theme.textPrimary)
            bar(fraction: fraction, tint: isBeaten ? Theme.orange : Theme.cyan)
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

    private func bar(fraction: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.gaugeIdle.opacity(0.6))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * CGFloat(fraction))
                    .shadow(color: tint.opacity(0.8), radius: 3)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 6)
    }

    private func recordLine(_ record: String, isBeaten: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 7))
            Text(record)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(isBeaten ? Theme.orange : Theme.cyan.opacity(0.85))
    }
}

#Preview {
    SprintCard(
        times: ["2,9 s", "5,8 s", "9,6 s", "4,1 s", "--"],
        records: ["2,4 s", "5,8 s", "9,1 s", "4,0 s", "6,8 s"],
        progress: [0.83, 1, 0.95, 0.98, 0],
        beaten: [1],
        isRunning: false,
        elapsedText: "")
        .padding()
        .background(.black)
}
