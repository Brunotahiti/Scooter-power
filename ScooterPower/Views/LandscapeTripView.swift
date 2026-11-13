import SwiftUI
import ScooterCore

/// Écran du trajet en paysage : le compteur en grand, puis la vitesse
/// maximale, les commandes et le temps 0–100 km/h.
/// Carte et Photo restent réservées au portrait.
struct LandscapeTripView: View {
    let model: TripViewModel
    let onTogglePause: () -> Void
    let onMain: () -> Void
    let onOpenSettings: () -> Void
    let onHistory: () -> Void
    let onStats: () -> Void
    let onSettings: () -> Void

    private static let bottomHeight: CGFloat = 64

    var body: some View {
        GeometryReader { proxy in
            let available: CGFloat = proxy.size.height - Self.bottomHeight - 10
            let byHeight: CGFloat = available / SpeedometerView.baseHeight
            // À l'échelle 1, le compteur est fait pour environ 400 pt de large.
            let byWidth: CGFloat = proxy.size.width / 400
            let scale: CGFloat = max(1, min(byHeight, byWidth))
            VStack(spacing: 10) {
                ZStack(alignment: .top) {
                    SpeedometerView(
                        speed: model.speedValue,
                        unit: model.speedUnit,
                        maxSpeed: model.speedometerMax,
                        labelStep: model.speedometerStep,
                        isAlert: model.speedAlertActive,
                        signalBars: model.state == .idle ? 4 : model.gpsSignalBars,
                        scale: scale)
                    HeaderView(
                        state: model.state,
                        detail: model.totalDurationText,
                        onHistory: onHistory,
                        onStats: onStats,
                        onSettings: onSettings,
                        onRecalibrate: { model.recalibrate() })
                }
                .frame(maxHeight: .infinity)
                bottomRow
                    .frame(height: Self.bottomHeight)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(backdrop.ignoresSafeArea())
    }

    /// Fond sombre avec des halos cyan et orange.
    private var backdrop: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Color(hex: 0x0B2A3A).opacity(0.9), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.3), startRadius: 20, endRadius: 460)
            RadialGradient(
                colors: [Color(hex: 0x3A1508).opacity(0.5), Color.clear],
                center: UnitPoint(x: 0.5, y: 1), startRadius: 10, endRadius: 320)
        }
    }

    // MARK: - Bas de l'écran

    private var bottomRow: some View {
        HStack(spacing: 12) {
            LandscapeTile(
                icon: "gauge.with.needle", title: L("Vitesse max"),
                value: model.maxSpeedText, unit: model.speedUnit)
            buttons
            if model.locationDenied {
                locationDenied
            } else {
                LandscapeTile(
                    icon: "bolt.fill", title: L("Accélération \(SpeedInterval.zeroTo100.label)"),
                    value: zeroTo100Text, unit: "")
            }
        }
    }

    /// Meilleur 0–100 du trajet, sinon le record tous trajets confondus.
    private var zeroTo100Text: String {
        guard let index = SpeedInterval.all.firstIndex(of: .zeroTo100) else { return "--" }
        let trip: String = model.sprintTexts.indices.contains(index) ? model.sprintTexts[index] : "--"
        if trip != "--" { return trip }
        return model.recordTexts.indices.contains(index) ? model.recordTexts[index] : "--"
    }

    private var locationDenied: some View {
        Button(action: onOpenSettings) {
            HStack(spacing: 6) {
                Image(systemName: "location.slash")
                Text("Position refusée · Ouvrir Réglages")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.orange)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var buttons: some View {
        let isIdle: Bool = model.state == .idle
        let isActive: Bool = model.state == .recording || model.state == .paused
        return HStack(spacing: 10) {
            if isActive {
                Button(action: onTogglePause) {
                    Image(systemName: model.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 21, weight: .bold))
                        .frame(width: 54, height: 54)
                        .background(Theme.card, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.cyan.opacity(0.45), lineWidth: 1.5))
                }
                .accessibilityLabel(model.state == .paused ? L("Reprendre") : L("Mettre en pause"))
            }
            Button(action: onMain) {
                Text(isIdle ? L("Démarrer") : L("Terminer"))
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 22)
                    .frame(height: 54)
                    .foregroundStyle(isIdle ? Color.black : Color.white)
                    .background(mainFill(isIdle: isIdle), in: Capsule())
                    .shadow(color: (isIdle ? Theme.cyan : Theme.red).opacity(0.5), radius: 10)
            }
        }
        .foregroundStyle(Theme.textPrimary)
    }

    private func mainFill(isIdle: Bool) -> LinearGradient {
        let colors: [Color] = isIdle
            ? [Color(hex: 0x4FE3FF), Theme.cyan]
            : [Color(hex: 0xF0504A), Color(hex: 0xC8302C)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

/// Tuile du bas de l'écran : icône, titre, valeur en cyan.
private struct LandscapeTile: View {
    let icon: String
    let title: String
    let value: String
    let unit: String

    var body: some View {
        let shape = HexagonFrame(tip: 22)
        let border = LinearGradient(
            colors: [Theme.orange.opacity(0.85), Theme.cyan.opacity(0.4), Theme.orange.opacity(0.85)],
            startPoint: .leading, endPoint: .trailing)
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.7), radius: 5)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundStyle(Theme.textPrimary.opacity(0.9))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 25, weight: .black))
                        .italic()
                        .monospacedDigit()
                        .foregroundStyle(Theme.cyan)
                    if !unit.isEmpty {
                        Text(verbatim: unit)
                            .font(.system(size: 16, weight: .bold))
                            .italic()
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55), in: shape)
        .overlay(shape.stroke(border, lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value + " " + unit)
    }
}
