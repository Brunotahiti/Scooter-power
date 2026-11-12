import SwiftUI

/// Grande carte : une icône, un titre, une valeur et son unité.
struct BigStatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.cyan)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(unit)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Theme.textPrimary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value) \(unit)")
    }
}

/// Carte à deux valeurs côte à côte.
struct DualStatCard: View {
    struct Item {
        let icon: String?
        let title: String
        let value: String
    }

    let first: Item
    let second: Item

    var body: some View {
        HStack(spacing: 8) {
            cell(first)
            Rectangle()
                .fill(Theme.cardBorder)
                .frame(width: 1, height: 28)
            cell(second)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func cell(_ item: Item) -> some View {
        HStack(spacing: 6) {
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.cyan)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Text(item.value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.value)
    }
}
