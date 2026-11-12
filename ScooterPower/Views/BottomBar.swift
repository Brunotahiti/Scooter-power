import SwiftUI
import ScooterCore

struct BottomBar: View {
    let state: TripState
    let onMap: () -> Void
    let onTogglePause: () -> Void
    let onMain: () -> Void
    let onPhoto: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            sideButton(icon: "map", label: L("Carte"), action: onMap)

            if state == .recording || state == .paused {
                Button(action: onTogglePause) {
                    Image(systemName: state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 50, height: 50)
                        .background(Theme.card, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.cyan.opacity(0.45), lineWidth: 1.5))
                }
                .accessibilityLabel(state == .paused ? L("Reprendre") : L("Mettre en pause"))
            }

            Button(action: onMain) {
                mainLabel
            }

            sideButton(icon: "camera", label: L("Photo"), action: onPhoto)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(Theme.background)
    }

    private var mainLabel: some View {
        let isIdle: Bool = state == .idle
        let colors: [Color] = isIdle
            ? [Color(hex: 0x4FE3FF), Theme.cyan]
            : [Color(hex: 0xF0504A), Color(hex: 0xC8302C)]
        let glow: Color = isIdle ? Theme.cyan : Theme.red
        return HStack(spacing: 10) {
            if isIdle {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
            }
            Text(isIdle ? L("Démarrer le trajet") : L("Terminer le trajet"))
                .font(.system(size: 19, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .foregroundStyle(isIdle ? Color.black : Color.white)
        .background(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom), in: Capsule())
        .shadow(color: glow.opacity(0.55), radius: 10)
    }

    private func sideButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .medium))
                Text(label)
                    .font(.system(size: 12))
            }
            .frame(width: 54, height: 50)
            .contentShape(Rectangle())
        }
    }
}
