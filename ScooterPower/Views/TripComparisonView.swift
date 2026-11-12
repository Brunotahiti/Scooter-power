import SwiftUI
import ScooterCore

/// Deux trajets de l'historique côte à côte. Sur chaque ligne, le meilleur
/// chiffre est mis en évidence.
struct TripComparisonView: View {
    /// Trajets du plus récent au plus ancien ; il en faut au moins deux.
    let trips: [TripRecord]

    @State private var firstIndex = 0
    @State private var secondIndex = 1

    private static let firstColor = Theme.cyan
    private static let secondColor = Theme.orange

    private var first: TripRecord? {
        trips.indices.contains(firstIndex) ? trips[firstIndex] : nil
    }

    private var second: TripRecord? {
        trips.indices.contains(secondIndex) ? trips[secondIndex] : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                pickers
                table
                legend
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Comparer")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Choix des trajets

    private var pickers: some View {
        HStack(alignment: .top, spacing: 10) {
            tripPicker(label: "Trajet A", selection: $firstIndex, color: Self.firstColor)
            tripPicker(label: "Trajet B", selection: $secondIndex, color: Self.secondColor)
        }
    }

    private func tripPicker(label: String, selection: Binding<Int>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Picker(label, selection: selection) {
                ForEach(trips.indices, id: \.self) { index in
                    Text(trips[index].title).tag(index)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Tableau

    @ViewBuilder
    private var table: some View {
        if let first, let second {
            let rows: [ComparisonRow] = TripComparison.rows(first.summary, second.summary)
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    line(rows[index])
                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Theme.cardBorder)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .cardStyle()
        }
    }

    private func line(_ row: ComparisonRow) -> some View {
        let a: String = Self.text(row.first, for: row.metric)
        let b: String = Self.text(row.second, for: row.metric)
        return HStack(spacing: 8) {
            value(a, wins: row.winner == .first, color: Self.firstColor, alignment: .leading)
            Text(Self.title(row.metric))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            value(b, wins: row.winner == .second, color: Self.secondColor, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.title(row.metric))
        .accessibilityValue(Self.spoken(row, a, b))
    }

    private func value(_ text: String, wins: Bool, color: Color, alignment: Alignment) -> some View {
        HStack(spacing: 4) {
            if wins, alignment == .trailing {
                Image(systemName: "trophy.fill").font(.system(size: 11))
            }
            Text(text)
                .font(.system(size: 17, weight: wins ? .heavy : .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if wins, alignment == .leading {
                Image(systemName: "trophy.fill").font(.system(size: 11))
            }
        }
        .foregroundStyle(wins ? color : Theme.textPrimary)
        .frame(width: 104, alignment: alignment)
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
            Text("Meilleur chiffre de la ligne. Distance et durées ne sont pas classées.")
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Textes

    private static func title(_ metric: ComparisonMetric) -> String {
        switch metric {
        case .distance: return "Distance"
        case .movingDuration: return "Durée de roulage"
        case .totalDuration: return "Durée totale"
        case .maxSpeed: return "Vitesse maximale"
        case .averageSpeed: return "Vitesse moyenne"
        case .sprint50: return "0–50 km/h"
        case .sprint80: return "0–80 km/h"
        case .peakAcceleration: return "Pic d'accélération"
        case .maxLeanLeft: return "Inclinaison gauche"
        case .maxLeanRight: return "Inclinaison droite"
        }
    }

    private static func text(_ value: Double?, for metric: ComparisonMetric) -> String {
        guard let value, value.isFinite else { return "--" }
        let digits: Int = metric.displayDigits
        switch metric {
        case .distance:
            return Formatters.decimal(value / 1000, digits: digits) + " km"
        case .movingDuration, .totalDuration:
            return Formatters.duration(value)
        case .maxSpeed, .averageSpeed:
            return Formatters.decimal(value, digits: digits) + " km/h"
        case .sprint50, .sprint80:
            return Formatters.decimal(value, digits: digits) + " s"
        case .peakAcceleration:
            return Formatters.decimal(value, digits: digits) + " m/s²"
        case .maxLeanLeft, .maxLeanRight:
            return Formatters.decimal(value, digits: digits) + "°"
        }
    }

    private static func spoken(_ row: ComparisonRow, _ a: String, _ b: String) -> String {
        var text: String = "Trajet A : " + a + ". Trajet B : " + b + "."
        switch row.winner {
        case .first: text += " Avantage au trajet A."
        case .second: text += " Avantage au trajet B."
        case .tie: text += " Égalité."
        case .none: break
        }
        return text
    }
}
