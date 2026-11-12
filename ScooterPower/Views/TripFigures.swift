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
        let units: UnitSystem = AppSettings.shared.units
        let distance: String = Formatters.decimal(units.distance(fromMeters: summary.distanceMeters), digits: 1)
            + " " + units.distanceUnit
        let top: String = Formatters.decimal(units.speed(fromKmh: summary.maxSpeedKmh), digits: 0) + " " + units.speedUnit
        let average: String = Formatters.decimal(units.speed(fromKmh: summary.averageSpeedKmh), digits: 0)
            + " " + units.speedUnit
        var entries: [(String, String)] = [
            (L("Distance"), distance),
            (L("Durée de roulage"), Formatters.duration(summary.movingDuration)),
            (L("Durée totale"), Formatters.duration(summary.totalDuration)),
            (L("Vitesse maximale"), top),
            (L("Vitesse moyenne"), average),
        ]
        for interval in SpeedInterval.all {
            entries.append((interval.label + " km/h", Self.sprint(summary.best(interval))))
        }
        entries.append((L("Pic d'accélération"), Formatters.signed(summary.peakAcceleration, digits: 1) + " m/s²"))
        entries.append((L("Inclinaison max. gauche"), Formatters.decimal(summary.maxLeanLeftDegrees, digits: 0) + "°"))
        entries.append((L("Inclinaison max. droite"), Formatters.decimal(summary.maxLeanRightDegrees, digits: 0) + "°"))
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
