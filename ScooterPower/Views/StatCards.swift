import SwiftUI

/// Grande carte : une icône, un titre, une valeur et son unité.
struct BigStatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.6), radius: 5)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(verbatim: unit)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Theme.textPrimary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value + " " + unit)
    }
}

/// Petite carte : une icône, un titre et une valeur déjà accompagnée de son unité.
struct SmallStatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.cyan)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
