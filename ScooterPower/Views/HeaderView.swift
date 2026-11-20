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
    var onGroupRide: () -> Void = {}
    var onGarage: () -> Void = {}
    var onLeaderboard: () -> Void = {}
    var onSegments: () -> Void = {}
    var onRewards: () -> Void = {}
    var onLiveShare: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            leading
            Spacer(minLength: 0)
            Menu {
                Button(L("Recalibrer l'inclinaison"), systemImage: "scope", action: onRecalibrate)
                    .disabled(state != .recording && state != .paused)
                Button(L("Balade de groupe"), systemImage: "person.3.fill", action: onGroupRide)
                Button(L("Position en direct"), systemImage: "location.fill.viewfinder", action: onLiveShare)
                Button(L("Statistiques"), systemImage: "chart.bar.fill", action: onStats)
                Button(L("Récompenses"), systemImage: "rosette", action: onRewards)
                Button(L("Segments"), systemImage: "flag.checkered", action: onSegments)
                Button(L("Classements"), systemImage: "trophy.fill", action: onLeaderboard)
                Button(L("Garage"), systemImage: "wrench.and.screwdriver.fill", action: onGarage)
                Button(L("Réglages"), systemImage: "gearshape", action: onSettings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 44, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L("Plus d'options"))
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
            .accessibilityLabel(L("Historique des trajets"))
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

    /// Simple point lumineux ; le texte reste lu par VoiceOver.
    private func pill(text: String, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .shadow(color: color, radius: 5)
            .frame(width: 30, height: 36)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }
}
