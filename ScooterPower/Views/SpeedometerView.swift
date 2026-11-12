import SwiftUI
import ScooterCore

/// Compteur en arc. `speed` est déjà dans l'unité affichée ; `nil` affiche `--`.
/// `scale` agrandit tout le compteur (1 = taille du portrait, 190 pt de haut).
struct SpeedometerView: View {
    let speed: Double?
    /// « km/h » ou « mph ».
    var unit: String = "km/h"
    /// Fin d'échelle, dans l'unité affichée.
    var maxSpeed: Double = 140
    /// Écart entre deux chiffres de l'échelle.
    var labelStep: Double = 20
    /// Vrai quand le seuil d'alerte est dépassé : le compteur passe au rouge.
    var isAlert: Bool = false
    var scale: CGFloat = 1

    static let baseHeight: CGFloat = 190

    private var tint: Color { isAlert ? Theme.red : Theme.cyan }
    /// L'arc couvre 200° : de 190° (0 km/h, à gauche) à −10° (140 km/h, à droite).
    private static let startAngle: Double = 190
    private static let sweep: Double = 200

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
        ZStack(alignment: .bottom) {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            readout
        }
        .frame(height: Self.baseHeight * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitesse actuelle")
        .accessibilityValue(speed == nil ? L("inconnue") : speedText + " " + unit)
    }

    private var readout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6 * scale) {
                Image(systemName: "location.north.fill")
                    .rotationEffect(.degrees(35))
                Text("GPS")
            }
            .font(.system(size: 15 * scale, weight: .semibold))
            .foregroundStyle(tint)

            Text(speedText)
                .font(.system(size: 72 * scale, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 74 * scale)
                .foregroundStyle(isAlert ? Theme.red : Theme.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: roundedSpeed)

            Text(verbatim: unit)
                .font(.system(size: 20 * scale, weight: .bold, design: .rounded))
            Text("Vitesse actuelle")
                .font(.system(size: 15 * scale))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let k: CGFloat = scale
        let labelPadding: CGFloat = 40 * k
        let byWidth: CGFloat = size.width / 2 - labelPadding
        let byHeight: CGFloat = (size.height - labelPadding - 26 * k) / 1.18
        let radius: CGFloat = min(byWidth, byHeight)
        guard radius > 20 else { return }
        let center = CGPoint(x: size.width / 2, y: labelPadding + radius)

        func point(at value: Double, radius r: CGFloat) -> CGPoint {
            let degrees: Double = Self.startAngle - Self.sweep * value / maxSpeed
            let radians: Double = degrees * Double.pi / 180
            let dx: CGFloat = r * CGFloat(cos(radians))
            let dy: CGFloat = r * CGFloat(sin(radians))
            return CGPoint(x: center.x + dx, y: center.y - dy)
        }

        let current: Double = fraction * maxSpeed
        let accent: Color = tint

        // Graduations : fines toutes les 2 unités, longues toutes les 10.
        let lastStep: Int = max(1, Int((maxSpeed / 2).rounded()))
        for step in 0...lastStep {
            let value: Double = Double(step) * 2
            let isMajor: Bool = step % 5 == 0
            let length: CGFloat = (isMajor ? 15 : 8) * k
            let width: CGFloat = (isMajor ? 2.5 : 1.2) * k
            let lit: Bool = value <= current && current > 0
            let color: Color = lit ? accent : Theme.gaugeIdle
            var tick = Path()
            tick.move(to: point(at: value, radius: radius))
            tick.addLine(to: point(at: value, radius: radius - length))
            context.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        // Arc parcouru, avec halo.
        if current > 0 {
            var arc = Path()
            let steps: Int = max(2, Int(current))
            for index in 0...steps {
                let value: Double = current * Double(index) / Double(steps)
                let p: CGPoint = point(at: value, radius: radius + 5 * k)
                if index == 0 {
                    arc.move(to: p)
                } else {
                    arc.addLine(to: p)
                }
            }
            let thick = StrokeStyle(lineWidth: 5 * k, lineCap: .round, lineJoin: .round)
            var glow = context
            glow.addFilter(.shadow(color: accent.opacity(0.9), radius: 7 * k))
            glow.stroke(arc, with: .color(accent), style: thick)

            var marker = Path()
            marker.move(to: point(at: current, radius: radius + 9 * k))
            marker.addLine(to: point(at: current, radius: radius - 20 * k))
            glow.stroke(marker, with: .color(accent), style: thick)
        }

        // Chiffres.
        for value in stride(from: 0.0, through: maxSpeed, by: max(1, labelStep)) {
            let label = Text(Formatters.decimal(value, digits: 0))
                .font(.system(size: 14 * k, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            context.draw(label, at: point(at: value, radius: radius + 24 * k))
        }
    }
}

#Preview {
    SpeedometerView(speed: 68)
        .padding()
        .background(.black)
}
