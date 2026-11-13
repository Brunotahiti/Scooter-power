import SwiftUI
import ScooterCore

/// Commandes posées en haut de l'écran, par-dessus le compteur : à gauche
/// l'état du trajet (ou l'historique à l'arrêt), à droite le menu.
struct HeaderView: View {
    let state: TripState
    /// Durée affichée à côté de l'état, en paysage où elle n'a pas d'autre place.
    var detail: String?
    let onHistory: () -> Void
    let onStats: () -> Void
    let onSettings: () -> Void
    let onRecalibrate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            leading
            Spacer(minLength: 0)
            Menu {
                Button("Recalibrer l'inclinaison", systemImage: "scope", action: onRecalibrate)
                    .disabled(state != .recording && state != .paused)
                Button("Statistiques", systemImage: "chart.bar.fill", action: onStats)
                Button("Réglages", systemImage: "gearshape", action: onSettings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 44, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Plus d'options")
        }
        .foregroundStyle(Theme.textPrimary)
    }

    @ViewBuilder
    private var leading: some View {
        switch state {
        case .idle:
            Button(action: onHistory) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 44, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Historique des trajets")
        case .recording:
            pill(text: withDetail(L("Enregistrement")), color: Theme.red)
        case .paused:
            pill(text: withDetail(L("En pause")), color: Theme.gaugeIdle)
        case .finished:
            EmptyView()
        }
    }

    private func withDetail(_ text: String) -> String {
        guard let detail, !detail.isEmpty else { return text }
        return text + " · " + detail
    }

    private func pill(text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.22), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.8), lineWidth: 1))
        .fixedSize()
    }
}
