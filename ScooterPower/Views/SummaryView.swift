import SwiftUI
import ScooterCore

struct SummaryView: View {
    let summary: TripSummary
    let onDone: () -> Void

    private var rows: [(String, String)] {
        [
            ("Distance", Formatters.decimal(summary.distanceMeters / 1000, digits: 1) + " km"),
            ("Durée de roulage", Formatters.duration(summary.movingDuration)),
            ("Durée totale", Formatters.duration(summary.totalDuration)),
            ("Vitesse maximale", Formatters.decimal(summary.maxSpeedKmh, digits: 0) + " km/h"),
            ("Vitesse moyenne", Formatters.decimal(summary.averageSpeedKmh, digits: 0) + " km/h"),
            ("Pic d'accélération", Formatters.signed(summary.peakAcceleration, digits: 1) + " m/s²"),
            ("Inclinaison max. gauche", Formatters.decimal(summary.maxLeanLeftDegrees, digits: 0) + "°"),
            ("Inclinaison max. droite", Formatters.decimal(summary.maxLeanRightDegrees, digits: 0) + "°"),
        ]
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Résumé du trajet")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 24)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack {
                        Text(row.0)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(row.1)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 14)
                    .accessibilityElement(children: .combine)
                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Theme.cardBorder)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .cardStyle()

            Spacer()

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
