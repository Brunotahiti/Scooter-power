import SwiftUI
import ScooterCore

/// Écran du trajet en paysage : compteur agrandi à gauche, l'essentiel à droite.
/// Carte et Photo restent réservées au portrait.
struct LandscapeTripView: View {
    let model: TripViewModel
    let onTogglePause: () -> Void
    let onMain: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 16) {
                speedometer(in: proxy.size)
                sidePanel
                    .frame(width: sideWidth(in: proxy.size))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Theme.background.ignoresSafeArea())
    }

    private func sideWidth(in size: CGSize) -> CGFloat {
        min(300, size.width * 0.36)
    }

    private func speedometer(in size: CGSize) -> some View {
        let available: CGFloat = size.width - sideWidth(in: size) - 16
        let byHeight: CGFloat = size.height / SpeedometerView.baseHeight
        // À l'échelle 1, le compteur occupe environ 290 pt de large.
        let byWidth: CGFloat = available / 290
        let scale: CGFloat = max(1, min(byHeight, byWidth))
        return SpeedometerView(
            speed: model.speedValue,
            unit: model.speedUnit,
            maxSpeed: model.speedometerMax,
            labelStep: model.speedometerStep,
            isAlert: model.speedAlertActive,
            scale: scale)
            .frame(width: available)
            .frame(maxHeight: .infinity)
    }

    private var sidePanel: some View {
        VStack(spacing: 8) {
            if model.locationDenied {
                locationDenied
            } else {
                status
            }
            HStack(spacing: 8) {
                LandscapeTile(
                    title: L("Vitesse max"), value: model.maxSpeedText,
                    unit: model.speedUnit, tint: Theme.textPrimary)
                LandscapeTile(title: L("Distance"), value: model.distanceText, unit: "", tint: Theme.textPrimary)
            }
            HStack(spacing: 8) {
                LandscapeTile(
                    title: L("Accélération"), value: model.accelerationText, unit: "m/s²",
                    tint: model.accelerationLevel.direction == 0 ? Theme.textPrimary : model.accelerationLevel.color)
                LandscapeTile(title: leanTitle, value: model.leanText, unit: "", tint: Theme.cyan)
            }
            Spacer(minLength: 0)
            buttons
        }
    }

    private var leanTitle: String {
        switch model.leanSide {
        case .left: return L("Incl. gauche")
        case .upright: return L("Inclinaison")
        case .right: return L("Incl. droite")
        }
    }

    private var status: some View {
        let text: String
        let color: Color
        switch model.state {
        case .idle:
            text = L("Prêt à partir")
            color = Theme.textSecondary
        case .recording:
            text = model.gpsWeak ? L("Signal GPS faible") : L("Enregistrement") + " · " + model.totalDurationText
            color = model.gpsWeak ? Theme.orange : Theme.red
        case .paused:
            text = L("En pause") + " · " + model.totalDurationText
            color = Theme.textSecondary
        case .finished:
            text = L("Trajet terminé")
            color = Theme.textSecondary
        }
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var locationDenied: some View {
        Button(action: onOpenSettings) {
            HStack(spacing: 6) {
                Image(systemName: "location.slash")
                Text("Position refusée · Ouvrir Réglages")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var buttons: some View {
        let isIdle: Bool = model.state == .idle
        let isActive: Bool = model.state == .recording || model.state == .paused
        return HStack(spacing: 8) {
            if isActive {
                Button(action: onTogglePause) {
                    Image(systemName: model.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 52, height: 52)
                        .background(Theme.card, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.cardBorder, lineWidth: 1))
                }
                .accessibilityLabel(model.state == .paused ? L("Reprendre") : L("Mettre en pause"))
            }
            Button(action: onMain) {
                Text(isIdle ? L("Démarrer") : L("Terminer"))
                    .font(.system(size: 19, weight: .bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(isIdle ? Color.black : Color.white)
                    .background(
                        isIdle ? Theme.cyan : Theme.finish,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .foregroundStyle(Theme.textPrimary)
    }
}

private struct LandscapeTile: View {
    let title: String
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value + " " + unit)
    }
}
