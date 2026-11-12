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
                        .overlay(Circle().strokeBorder(Theme.cardBorder, lineWidth: 1))
                }
                .accessibilityLabel(state == .paused ? L("Reprendre") : L("Mettre en pause"))
            }

            Button(action: onMain) {
                Text(state == .idle ? L("Démarrer le trajet") : L("Terminer le trajet"))
                    .font(.system(size: 19, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(state == .idle ? Color.black : Color.white)
                    .background(
                        state == .idle ? Theme.cyan : Theme.finish,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            sideButton(icon: "camera", label: L("Photo"), action: onPhoto)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(Theme.background)
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
