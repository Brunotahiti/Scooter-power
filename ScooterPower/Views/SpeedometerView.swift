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
        .aspectRatio(358.0 / 206.0, contentMode: .fit)
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
                .font(.system(size: 84, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 86)
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
        let byWidth: CGFloat = size.width / 2 - Self.labelPadding
        let byHeight: CGFloat = (size.height - Self.labelPadding - 26) / 1.18
        let radius: CGFloat = min(byWidth, byHeight)
        guard radius > 20 else { return }
        let center = CGPoint(x: size.width / 2, y: Self.labelPadding + radius)

        func point(at value: Double, radius r: CGFloat) -> CGPoint {
            let degrees: Double = Self.startAngle - Self.sweep * value / Self.maxSpeed
            let radians: Double = degrees * Double.pi / 180
            let dx: CGFloat = r * CGFloat(cos(radians))
            let dy: CGFloat = r * CGFloat(sin(radians))
            return CGPoint(x: center.x + dx, y: center.y - dy)
        }

        let current: Double = fraction * Self.maxSpeed

        // Graduations : fines tous les 2 km/h, longues tous les 10.
        for step in 0...70 {
            let value: Double = Double(step) * 2
            let isMajor: Bool = step % 5 == 0
            let length: CGFloat = isMajor ? 15 : 8
            let width: CGFloat = isMajor ? 2.5 : 1.2
            let lit: Bool = value <= current && current > 0
            let color: Color = lit ? Theme.cyan : Theme.gaugeIdle
            var tick = Path()
            tick.move(to: point(at: value, radius: radius))
            tick.addLine(to: point(at: value, radius: radius - length))
            context.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        // Arc parcouru, avec halo.
        if current > 0 {
            var arc = Path()
            let steps = max(2, Int(current))
            for index in 0...steps {
                let value: Double = current * Double(index) / Double(steps)
                let p: CGPoint = point(at: value, radius: radius + 5)
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
