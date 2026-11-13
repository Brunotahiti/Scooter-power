import SwiftUI
import ScooterCore

/// Compteur de vitesse : pastille GPS, vitesse dans un cadre hexagonal, puis
/// une échelle graduée au-dessus d'une barre à segments inclinés, du cyan au
/// rouge. `speed` est déjà dans l'unité affichée ; `nil` affiche `--`.
/// `scale` agrandit l'ensemble (1 en portrait).
struct SpeedometerView: View {
    let speed: Double?
    /// « km/h » ou « mph ».
    var unit: String = "km/h"
    /// Fin d'échelle, dans l'unité affichée.
    var maxSpeed: Double = 140
    /// Écart entre deux chiffres de l'échelle.
    var labelStep: Double = 20
    /// Vrai quand le seuil d'alerte est dépassé : la vitesse passe au rouge.
    var isAlert: Bool = false
    /// Qualité du signal GPS, de 0 à 4 barres.
    var signalBars: Int = 4
    var scale: CGFloat = 1

    /// Hauteur totale à l'échelle 1.
    static let baseHeight: CGFloat = 196

    private var fraction: Double {
        min(1, max(0, (speed ?? 0) / maxSpeed))
    }

    private var speedText: String {
        speed.map { Formatters.decimal($0, digits: 0) } ?? "--"
    }

    private var roundedSpeed: Int? {
        speed.map { Int($0.rounded()) }
    }

    var body: some View {
        VStack(spacing: 6 * scale) {
            gpsBadge
            panel
            SpeedBar(fraction: fraction, maxSpeed: maxSpeed, labelStep: labelStep, scale: scale)
                .frame(height: 58 * scale)
        }
        .frame(height: Self.baseHeight * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitesse actuelle")
        .accessibilityValue(speed == nil ? L("inconnue") : speedText + " " + unit)
    }

    // MARK: - Pastille GPS

    private var gpsBadge: some View {
        let shape = HexagonFrame(tip: 12 * scale)
        return HStack(spacing: 6 * scale) {
            Image(systemName: "location.north.fill")
                .rotationEffect(.degrees(35))
            Text(verbatim: "GPS")
            signal
        }
        .font(.system(size: 15 * scale, weight: .heavy))
        .foregroundStyle(signalBars == 0 ? Theme.textSecondary : Theme.cyan)
        .padding(.horizontal, 22 * scale)
        .frame(height: 28 * scale)
        .background(Color.black.opacity(0.55), in: shape)
        .overlay(shape.stroke(Theme.cyan.opacity(0.35), lineWidth: 1))
    }

    /// Quatre barres de hauteur croissante ; celles au-delà du niveau sont éteintes.
    private var signal: some View {
        HStack(alignment: .bottom, spacing: 2 * scale) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < signalBars ? Theme.cyan : Theme.gaugeIdle)
                    .frame(width: 4 * scale, height: (5 + 3.5 * CGFloat(index)) * scale)
            }
        }
    }

    // MARK: - Cadre de la vitesse

    private var panel: some View {
        let shape = HexagonFrame(tip: 34 * scale)
        let accent: Color = isAlert ? Theme.red : Theme.cyan
        let border = LinearGradient(
            colors: [Theme.orange.opacity(0.9), accent, accent, Theme.orange.opacity(0.9)],
            startPoint: .leading, endPoint: .trailing)
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8 * scale) {
                Text(speedText)
                    .font(.system(size: 68 * scale, weight: .black))
                    .italic()
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: roundedSpeed)
                Text(verbatim: unit)
                    .font(.system(size: 24 * scale, weight: .heavy))
                    .italic()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(isAlert ? Theme.red : Theme.textPrimary)
            .shadow(color: accent.opacity(0.45), radius: 8)

            Text("Vitesse actuelle")
                .font(.system(size: 15 * scale))
                .italic()
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 46 * scale)
        .frame(maxWidth: 330 * scale)
        .frame(height: 98 * scale)
        .background(Color.black.opacity(0.6), in: shape)
        .overlay(shape.stroke(border, lineWidth: 2 * scale))
        .shadow(color: accent.opacity(0.5), radius: 10)
    }
}

/// Rectangle aux extrémités en pointe.
struct HexagonFrame: Shape {
    /// Longueur de chaque pointe.
    let tip: CGFloat

    func path(in rect: CGRect) -> Path {
        let t: CGFloat = min(tip, rect.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + t, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Échelle graduée et barre de vitesse à segments inclinés.
private struct SpeedBar: View {
    /// Part de l'échelle atteinte, de 0 à 1.
    let fraction: Double
    let maxSpeed: Double
    let labelStep: Double
    let scale: CGFloat

    private static let segments = 44
    /// Jusqu'ici la barre est cyan, puis jaune, orange et enfin rouge.
    private static let warmStart: Double = 0.58
    private static let hotStart: Double = 0.66
    private static let redStart: Double = 0.80

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
    }

    private static func color(at position: Double) -> Color {
        if position < warmStart { return Theme.cyan }
        if position < hotStart { return Color(hex: 0xF5D90A) }
        if position < redStart { return Theme.orange }
        return Theme.red
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let k: CGFloat = scale
        let labelHeight: CGFloat = 26 * k
        let barHeight: CGFloat = size.height - labelHeight
        guard barHeight > 8, size.width > 60 else { return }
        let barTop: CGFloat = labelHeight
        let tip: CGFloat = barHeight / 2

        // La zone utile laisse les pointes du cadre libres.
        let innerLeft: CGFloat = tip * 1.25
        let innerWidth: CGFloat = size.width - innerLeft * 2

        func x(at position: Double) -> CGFloat {
            innerLeft + innerWidth * CGFloat(position)
        }

        // Chiffres et repères de l'échelle.
        for value in stride(from: 0.0, through: maxSpeed, by: max(1, labelStep)) {
            let position: Double = value / maxSpeed
            let label = Text(Formatters.decimal(value, digits: 0))
                .font(.system(size: 13 * k, weight: .bold))
                .italic()
                .foregroundColor(Theme.textPrimary)
            context.draw(label, at: CGPoint(x: x(at: position), y: 8 * k))
            var tick = Path()
            tick.move(to: CGPoint(x: x(at: position), y: 17 * k))
            tick.addLine(to: CGPoint(x: x(at: position), y: labelHeight - 2 * k))
            context.stroke(tick, with: .color(Theme.textPrimary.opacity(0.9)), lineWidth: 1.5 * k)
        }

        // Cadre de la barre, cyan à gauche et rouge à droite.
        let frame = CGRect(x: 0, y: barTop, width: size.width, height: barHeight)
        let outline: Path = HexagonFrame(tip: tip).path(in: frame.insetBy(dx: 1.5 * k, dy: 1.5 * k))
        let outlineColors = Gradient(stops: [
            .init(color: Theme.cyan, location: 0),
            .init(color: Theme.cyan, location: Self.warmStart),
            .init(color: Theme.orange, location: Self.redStart),
            .init(color: Theme.red, location: 1),
        ])
        var glow = context
        glow.addFilter(.shadow(color: Theme.cyan.opacity(0.6), radius: 6 * k))
        glow.stroke(
            outline,
            with: .linearGradient(
                outlineColors,
                startPoint: CGPoint(x: 0, y: frame.midY), endPoint: CGPoint(x: size.width, y: frame.midY)),
            lineWidth: 2 * k)

        // Segments inclinés : vifs jusqu'à la vitesse courante, éteints au-delà.
        let inset: CGFloat = 6 * k
        let top: CGFloat = barTop + inset
        let bottom: CGFloat = barTop + barHeight - inset
        let slant: CGFloat = (bottom - top) * 0.45
        let step: CGFloat = innerWidth / CGFloat(Self.segments)
        let width: CGFloat = step * 0.72
        for index in 0..<Self.segments {
            let position: Double = (Double(index) + 0.5) / Double(Self.segments)
            let left: CGFloat = innerLeft + step * CGFloat(index)
            var segment = Path()
            segment.move(to: CGPoint(x: left + slant, y: top))
            segment.addLine(to: CGPoint(x: left + slant + width, y: top))
            segment.addLine(to: CGPoint(x: left + width, y: bottom))
            segment.addLine(to: CGPoint(x: left, y: bottom))
            segment.closeSubpath()
            let lit: Bool = position <= fraction && fraction > 0
            let color: Color = Self.color(at: position)
            context.fill(segment, with: .color(color.opacity(lit ? 1 : 0.22)))
        }

        // Repère de la vitesse courante.
        if fraction > 0 {
            let position: CGFloat = x(at: fraction)
            var marker = Path()
            marker.move(to: CGPoint(x: position + slant * 0.9, y: barTop - 3 * k))
            marker.addLine(to: CGPoint(x: position - slant * 0.9, y: barTop + barHeight + 3 * k))
            var markerGlow = context
            markerGlow.addFilter(.shadow(color: Self.color(at: fraction).opacity(0.95), radius: 7 * k))
            markerGlow.stroke(
                marker, with: .color(Color.white.opacity(0.95)),
                style: StrokeStyle(lineWidth: 5 * k, lineCap: .round))
        }
    }
}

#Preview {
    SpeedometerView(speed: 112)
        .padding()
        .background(.black)
}
