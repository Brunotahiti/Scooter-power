import SwiftUI
import ScooterCore

struct HeaderView: View {
    let state: TripState
    let onRecalibrate: () -> Void

    private var title: String {
        switch state {
        case .idle: return "Prêt à partir"
        case .recording: return "Trajet en cours"
        case .paused: return "En pause"
        case .finished: return "Trajet terminé"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "scooter")
                .font(.system(size: 22, weight: .medium))
            Rectangle()
                .fill(Theme.gaugeIdle)
                .frame(width: 1, height: 22)
            Text(title)
                .font(.system(size: 21, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            statusPill

            Spacer(minLength: 0)

            Menu {
                Button("Recalibrer l'inclinaison", systemImage: "scope", action: onRecalibrate)
                    .disabled(state != .recording && state != .paused)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Plus d'options")
        }
        .foregroundStyle(Theme.textPrimary)
    }

    @ViewBuilder
    private var statusPill: some View {
        switch state {
        case .recording:
            pill(text: "Enregistrement", color: Theme.red)
        case .paused:
            pill(text: "En pause", color: Theme.gaugeIdle)
        case .idle, .finished:
            EmptyView()
        }
    }

    private func pill(text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.22), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.8), lineWidth: 1))
        .fixedSize()
    }
}
