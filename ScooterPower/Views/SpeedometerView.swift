import SwiftUI
import ScooterCore

/// Compteur en arc de 0 à 140 km/h. `speedKmh` à `nil` affiche `--`.
struct SpeedometerView: View {
    let speedKmh: Double?

    private static let maxSpeed = 140.0
    /// L'arc couvre 200° : de 190° (0 km/h, à gauche) à −10° (140 km/h, à droite).
    private static let startAngle = 190.0
    private static let sweep = 200.0
    private static let labelPadding: CGFloat = 40

    private var fraction: Double {
        min(1, max(0, (speedKmh ?? 0) / Self.maxSpeed))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            readout
        }
        .aspectRatio(358.0 / 226.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitesse actuelle")
        .accessibilityValue(speedKmh.map { Formatters.decimal($0, digits: 0) + " kilomètres par heure" } ?? "inconnue")
    }

    private var readout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "location.north.fill")
                    .rotationEffect(.degrees(35))
                Text("GPS")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.cyan)

            Text(speedKmh.map { Formatters.decimal($0, digits: 0) } ?? "--")
                .font(.system(size: 92, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 96)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: speedKmh.map { Int($0.rounded()) })

            Text("km/h")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("Vitesse actuelle")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width / 2 - Self.labelPadding, (size.height - Self.labelPadding - 26) / 1.18)
        guard radius > 20 else { return }
        let center = CGPoint(x: size.width / 2, y: Self.labelPadding + radius)

        func point(at value: Double, radius r: CGFloat) -> CGPoint {
            let degrees = Self.startAngle - Self.sweep * value / Self.maxSpeed
            let radians = degrees * .pi / 180
            return CGPoint(x: center.x + r * CGFloat(cos(radians)), y: center.y - r * CGFloat(sin(radians)))
        }

        let current = fraction * Self.maxSpeed

        // Graduations : fines tous les 2 km/h, longues tous les 10.
        for step in 0...70 {
            let value = Double(step) * 2
            let isMajor = step % 5 == 0
            var tick = Path()
            tick.move(to: point(at: value, radius: radius))
            tick.addLine(to: point(at: value, radius: radius - (isMajor ? 15 : 8)))
            let lit = value <= current && current > 0
            context.stroke(
                tick,
                with: .color(lit ? Theme.cyan : Theme.gaugeIdle),
                style: StrokeStyle(lineWidth: isMajor ? 2.5 : 1.2, lineCap: .round))
        }

        // Arc parcouru, avec halo.
        if current > 0 {
            var arc = Path()
            let steps = max(2, Int(current))
            for index in 0...steps {
                let p = point(at: current * Double(index) / Double(steps), radius: radius + 5)
                if index == 0 {
                    arc.move(to: p)
                } else {
                    arc.addLine(to: p)
                }
            }
            var glow = context
            glow.addFilter(.shadow(color: Theme.cyan.opacity(0.9), radius: 7))
            glow.stroke(arc, with: .color(Theme.cyan), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            var marker = Path()
            marker.move(to: point(at: current, radius: radius + 9))
            marker.addLine(to: point(at: current, radius: radius - 20))
            glow.stroke(marker, with: .color(Theme.cyan), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }

        // Chiffres.
        for value in stride(from: 0.0, through: Self.maxSpeed, by: 20) {
            let label = Text(Formatters.decimal(value, digits: 0))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            context.draw(label, at: point(at: value, radius: radius + 24))
        }
    }
}

#Preview {
    SpeedometerView(speedKmh: 68)
        .padding()
        .background(.black)
}
