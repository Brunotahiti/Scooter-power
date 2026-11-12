import SwiftUI
import ScooterCore

/// Les chiffres d'un trajet, en lignes. Partagé par le résumé et l'historique.
struct TripFigures: View {
    let summary: TripSummary

    private struct Row: Identifiable {
        let id: Int
        let title: String
        let value: String
    }

    private var rows: [Row] {
        let entries: [(String, String)] = [
            ("Distance", Formatters.decimal(summary.distanceMeters / 1000, digits: 1) + " km"),
            ("Durée de roulage", Formatters.duration(summary.movingDuration)),
            ("Durée totale", Formatters.duration(summary.totalDuration)),
            ("Vitesse maximale", Formatters.decimal(summary.maxSpeedKmh, digits: 0) + " km/h"),
            ("Vitesse moyenne", Formatters.decimal(summary.averageSpeedKmh, digits: 0) + " km/h"),
            ("0–50 km/h", Self.sprint(summary.best50)),
            ("0–80 km/h", Self.sprint(summary.best80)),
            ("Pic d'accélération", Formatters.signed(summary.peakAcceleration, digits: 1) + " m/s²"),
            ("Inclinaison max. gauche", Formatters.decimal(summary.maxLeanLeftDegrees, digits: 0) + "°"),
            ("Inclinaison max. droite", Formatters.decimal(summary.maxLeanRightDegrees, digits: 0) + "°"),
        ]
        var result: [Row] = []
        for index in entries.indices {
            result.append(Row(id: index, title: entries[index].0, value: entries[index].1))
        }
        return result
    }

    private static func sprint(_ time: TimeInterval?) -> String {
        guard let time else { return "--" }
        return Formatters.decimal(time, digits: 1) + " s"
    }

    var body: some View {
        let all: [Row] = rows
        return VStack(spacing: 0) {
            ForEach(all) { row in
                line(row, isLast: row.id == all.count - 1)
            }
        }
        .padding(.horizontal, 16)
        .cardStyle()
    }

    private func line(_ row: Row, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(row.title)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(row.value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.vertical, 11)
            .accessibilityElement(children: .combine)
            if !isLast {
                Rectangle()
                    .fill(Theme.cardBorder)
                    .frame(height: 1)
            }
        }
    }
}
