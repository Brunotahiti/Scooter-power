import Charts
import SwiftUI
import ScooterCore

/// Écran du trajet en paysage : grand cadran à gauche ; à droite l'état, quatre
/// tuiles, le graphe d'accélération et les boutons.
/// Carte et Photo restent réservées au portrait.
struct LandscapeTripView: View {
    let model: TripViewModel
    let onTogglePause: () -> Void
    let onMain: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let gauge: CGFloat = min(proxy.size.height, proxy.size.width * 0.52)
            HStack(spacing: 14) {
                LandscapeSpeedometer(
                    speed: model.speedValue,
                    unit: model.speedUnit,
                    maxSpeed: model.speedometerMax,
                    labelStep: model.speedometerStep,
                    isAlert: model.speedAlertActive,
                    signalBars: model.gpsSignalBars)
                    .frame(width: gauge, height: proxy.size.height)
                sidePanel
            }
            .overlay(alignment: .bottomLeading) {
                accuracyBadge
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(backdrop.ignoresSafeArea())
    }

    /// Fond sombre avec un halo bleuté derrière le cadran.
    private var backdrop: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Color(hex: 0x0B2A3A).opacity(0.9), Color.clear],
                center: UnitPoint(x: 0.28, y: 0.5), startRadius: 20, endRadius: 420)
            RadialGradient(
                colors: [Color(hex: 0x3A1508).opacity(0.5), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.75), startRadius: 10, endRadius: 260)
        }
    }

    // MARK: - Précision GPS

    private var accuracyBadge: some View {
        let accuracy: String = model.gpsAccuracyText ?? ""
        let hasFix: Bool = model.gpsAccuracyText != nil
        let dot: Color = signalColor
        return HStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.cyan)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(dot)
                        .frame(width: 8, height: 8)
                    Text(verbatim: "GPS")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(hasFix ? L("Précision : \(accuracy)") : L("Recherche du signal"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .lineLimit(1)
        .padding(.leading, 4)
        .padding(.bottom, 2)
        .opacity(model.state == .idle ? 0 : 1)
        .accessibilityElement(children: .combine)
    }

    private var signalColor: Color {
        switch model.gpsSignalBars {
        case 3...: return Color(hex: 0x34D058)
        case 1...2: return Theme.orange
        default: return Theme.red
        }
    }

    // MARK: - Panneau de droite

    private var sidePanel: some View {
        VStack(spacing: 8) {
            if model.locationDenied {
                locationDenied
            } else {
                status
            }
            HStack(spacing: 8) {
                LandscapeTile(
                    icon: "gauge.with.needle", title: L("Vitesse max"),
                    value: model.maxSpeedText, unit: model.speedUnit, tint: Theme.textPrimary)
                LandscapeTile(
                    icon: "mappin.and.ellipse", title: L("Distance"),
                    value: model.distanceText, unit: "", tint: Theme.textPrimary)
            }
            HStack(spacing: 8) {
                LandscapeTile(
                    icon: "bolt.fill", title: L("Accélération"),
                    value: model.accelerationText, unit: "m/s²", tint: accelerationTint)
                LandscapeTile(icon: "angle", title: leanTitle, value: model.leanText, unit: "", tint: Theme.textPrimary)
            }
            LandscapeAccelerationChart(history: model.accelerationHistory)
            buttons
        }
        .frame(maxWidth: .infinity)
    }

    private var accelerationTint: Color {
        model.accelerationLevel.direction == 0 ? Theme.textPrimary : model.accelerationLevel.color
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
            if model.gpsWeak {
                text = L("Signal GPS faible")
                color = Theme.orange
            } else {
                text = L("Enregistrement") + " · " + model.totalDurationText
                color = Theme.red
            }
        case .paused:
            text = L("En pause") + " · " + model.totalDurationText
            color = Theme.textSecondary
        case .finished:
            text = L("Trajet terminé")
            color = Theme.textSecondary
        }
        return HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .shadow(color: color.opacity(0.9), radius: 4)
            Text(text)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
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
        return HStack(spacing: 10) {
            if isActive {
                Button(action: onTogglePause) {
                    Image(systemName: model.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 56, height: 56)
                        .background(Theme.card, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.cyan.opacity(0.45), lineWidth: 1.5))
                }
                .accessibilityLabel(model.state == .paused ? L("Reprendre") : L("Mettre en pause"))
            }
            Button(action: onMain) {
                Text(isIdle ? L("Démarrer") : L("Terminer"))
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(isIdle ? Color.black : Color.white)
                    .background(mainFill(isIdle: isIdle), in: Capsule())
                    .shadow(color: (isIdle ? Theme.cyan : Theme.red).opacity(0.5), radius: 10)
            }
        }
        .foregroundStyle(Theme.textPrimary)
    }

    private func mainFill(isIdle: Bool) -> LinearGradient {
        let colors: [Color] = isIdle ? [Theme.cyan, Theme.cyan] : [Color(hex: 0xF0504A), Color(hex: 0xC8302C)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

/// Tuile du panneau de droite : icône, titre, valeur.
private struct LandscapeTile: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.7), radius: 5)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    if !unit.isEmpty {
                        Text(verbatim: unit)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.cyan.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value + " " + unit)
    }
}

/// Graphe de l'accélération des 30 dernières secondes. Les freinages sont tracés à zéro.
private struct LandscapeAccelerationChart: View {
    let history: [Double]

    private struct Point: Identifiable {
        let id: Int
        let value: Double
    }

    private var points: [Point] {
        let offset: Int = AccelerationAnalyzer.historyCapacity - history.count
        var result: [Point] = []
        result.reserveCapacity(history.count)
        for index in history.indices {
            result.append(Point(id: offset + index, value: max(0, history[index])))
        }
        return result
    }

    /// Haut de l'échelle : au moins 1 m/s², sinon le pic arrondi au demi supérieur.
    private var top: Double {
        let peak: Double = history.max() ?? 0
        return max(1, (peak * 2).rounded(.up) / 2)
    }

    var body: some View {
        let data: [Point] = points
        let ceiling: Double = top
        let lastIndex: Int = AccelerationAnalyzer.historyCapacity - 1
        return VStack(alignment: .leading, spacing: 2) {
            Text("Accélération (m/s²)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Chart {
                ForEach(data) { point in
                    AreaMark(x: .value("Temps", point.id), y: .value("Accélération", point.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(fill)
                    LineMark(x: .value("Temps", point.id), y: .value("Accélération", point.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Theme.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                if let last = data.last {
                    PointMark(x: .value("Temps", last.id), y: .value("Accélération", last.value))
                        .foregroundStyle(Theme.cyan)
                        .symbolSize(50)
                }
            }
            .chartXScale(domain: 0...lastIndex)
            .chartYScale(domain: 0.0...ceiling)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, ceiling / 2, ceiling]) { mark in
                    AxisGridLine().foregroundStyle(Theme.cardBorder)
                    AxisValueLabel {
                        Text(verbatim: label(for: mark))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.cyan.opacity(0.35), lineWidth: 1))
    }

    private var fill: LinearGradient {
        LinearGradient(
            colors: [Theme.cyan.opacity(0.45), Theme.cyan.opacity(0.03)],
            startPoint: .top, endPoint: .bottom)
    }

    private func label(for mark: AxisValue) -> String {
        guard let value = mark.as(Double.self) else { return "" }
        return Formatters.decimal(value, digits: 1)
    }
}
