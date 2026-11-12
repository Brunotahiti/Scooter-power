import SwiftUI
import ScooterCore

/// Grand cadran circulaire du mode paysage : échelle sur 250°, arc de
/// progression lumineux, zone orange en haut d'échelle, vitesse au centre.
struct LandscapeSpeedometer: View {
    /// Vitesse dans l'unité affichée ; `nil` affiche `--`.
    let speed: Double?
    let unit: String
    let maxSpeed: Double
    let labelStep: Double
    /// Seuil d'alerte dépassé : la vitesse passe au rouge.
    let isAlert: Bool
    /// Qualité du signal GPS, de 0 à 4 barres.
    let signalBars: Int

    /// 0 est en bas à gauche (215°), la fin d'échelle en bas à droite (−35°).
    private static let startAngle: Double = 215
    private static let sweep: Double = 250
    /// Part de l'échelle à partir de laquelle commence la zone orange.
    private static let hotZone: Double = 100.0 / 140.0

    private var fraction: Double {
        min(1, max(0, (speed ?? 0) / maxSpeed))
    }

    private var speedText: String {
        speed.map { Formatters.decimal($0, digits: 0) } ?? "--"
    }

    var body: some View {
        GeometryReader { proxy in
            let side: CGFloat = min(proxy.size.width, proxy.size.height)
            ZStack {
                Canvas { context, size in
                    draw(in: &context, size: size, side: side)
                }
                readout(side: side)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitesse actuelle")
        .accessibilityValue(speed == nil ? L("inconnue") : speedText + " " + unit)
    }

    // MARK: - Centre

    private func readout(side: CGFloat) -> some View {
        let k: CGFloat = side / 360
        return VStack(spacing: 0) {
            gpsRow(k: k)
            Text(speedText)
                .font(.system(size: 104 * k, weight: .black))
                .italic()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 190 * k, height: 104 * k)
                .foregroundStyle(isAlert ? Theme.red : Theme.textPrimary)
                .shadow(color: (isAlert ? Theme.red : Theme.cyan).opacity(0.45), radius: 10 * k)
                .contentTransition(.numericText())
            Text(verbatim: unit)
                .font(.system(size: 24 * k, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Vitesse actuelle")
                .font(.system(size: 15 * k))
                .foregroundStyle(Theme.textPrimary.opacity(0.85))
                .padding(.top, 4 * k)
        }
        .offset(y: 4 * k)
    }

    private func gpsRow(k: CGFloat) -> some View {
        HStack(spacing: 5 * k) {
            Image(systemName: "location.north.fill")
                .rotationEffect(.degrees(35))
            Text(verbatim: "GPS")
            signal(k: k)
        }
        .font(.system(size: 16 * k, weight: .bold))
        .foregroundStyle(signalBars == 0 ? Theme.textSecondary : Theme.cyan)
    }

    /// Quatre barres de hauteur croissante ; celles au-delà du niveau sont éteintes.
    private func signal(k: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 2 * k) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1 * k)
                    .fill(index < signalBars ? Theme.cyan : Theme.gaugeIdle)
                    .frame(width: 3.5 * k, height: (5 + 3 * CGFloat(index)) * k)
            }
        }
    }

    // MARK: - Cadran

    private func draw(in context: inout GraphicsContext, size: CGSize, side: CGFloat) {
        let k: CGFloat = side / 360
        let radius: CGFloat = side / 2 - 8 * k
        guard radius > 40 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        func point(at value: Double, radius r: CGFloat) -> CGPoint {
            let degrees: Double = Self.startAngle - Self.sweep * value / maxSpeed
            let radians: Double = degrees * Double.pi / 180
            let dx: CGFloat = r * CGFloat(cos(radians))
            let dy: CGFloat = r * CGFloat(sin(radians))
            return CGPoint(x: center.x + dx, y: center.y - dy)
        }

        /// Arc de `from` à `to` (dans l'unité affichée), tracé point par point.
        func arc(from: Double, to: Double, radius r: CGFloat) -> Path {
            var path = Path()
            let steps: Int = max(2, Int(abs(to - from) / maxSpeed * 120))
            for index in 0...steps {
                let value: Double = from + (to - from) * Double(index) / Double(steps)
                let p: CGPoint = point(at: value, radius: r)
                if index == 0 {
                    path.move(to: p)
                } else {
                    path.addLine(to: p)
                }
            }
            return path
        }

        let left = CGPoint(x: center.x - radius, y: center.y)
        let right = CGPoint(x: center.x + radius, y: center.y)
        let sweepColors = Gradient(colors: [Theme.cyan, Color(hex: 0x2A6BFF), Theme.orange])
        let rimShading: GraphicsContext.Shading = .linearGradient(sweepColors, startPoint: left, endPoint: right)

        // Anneau extérieur lumineux, cyan à gauche, orange à droite.
        let rim = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        var halo = context
        halo.addFilter(.shadow(color: Theme.cyan.opacity(0.55), radius: 10 * k))
        halo.stroke(rim, with: rimShading, lineWidth: 3 * k)

        // Anneau intérieur, autour de la vitesse.
        let innerRadius: CGFloat = radius * 0.58
        let inner = Path(ellipseIn: CGRect(
            x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2))
        context.stroke(inner, with: rimShading, lineWidth: 1.5 * k)

        // Graduations : fines toutes les 2 unités, longues toutes les 10.
        let tickRadius: CGFloat = radius - 8 * k
        let lastStep: Int = max(1, Int((maxSpeed / 2).rounded()))
        for step in 0...lastStep {
            let value: Double = Double(step) * 2
            let isMajor: Bool = step % 5 == 0
            let length: CGFloat = (isMajor ? 15 : 8) * k
            let opacity: Double = isMajor ? 0.9 : 0.35
            var tick = Path()
            tick.move(to: point(at: value, radius: tickRadius))
            tick.addLine(to: point(at: value, radius: tickRadius - length))
            context.stroke(
                tick, with: .color(Theme.textPrimary.opacity(opacity)),
                style: StrokeStyle(lineWidth: (isMajor ? 2.2 : 1) * k, lineCap: .round))
        }

        // Zone orange en haut d'échelle.
        let hotStart: Double = maxSpeed * Self.hotZone
        let hotRadius: CGFloat = radius * 0.70
        let hotColors = Gradient(colors: [Theme.orange, Theme.red])
        let hot: Path = arc(from: hotStart, to: maxSpeed, radius: hotRadius)
        var hotGlow = context
        hotGlow.addFilter(.shadow(color: Theme.orange.opacity(0.8), radius: 8 * k))
        hotGlow.stroke(
            hot,
            with: .linearGradient(hotColors, startPoint: point(at: hotStart, radius: hotRadius),
                                  endPoint: point(at: maxSpeed, radius: hotRadius)),
            style: StrokeStyle(lineWidth: 5 * k, lineCap: .round))

        // Arc de progression et aiguille.
        let current: Double = fraction * maxSpeed
        let progressRadius: CGFloat = radius - 32 * k
        let accent: Color = isAlert ? Theme.red : Theme.cyan
        if current > 0 {
            let cool: Double = min(current, hotStart)
            var glow = context
            glow.addFilter(.shadow(color: accent.opacity(0.9), radius: 9 * k))
            glow.stroke(
                arc(from: 0, to: cool, radius: progressRadius), with: .color(accent),
                style: StrokeStyle(lineWidth: 10 * k, lineCap: .round, lineJoin: .round))
            if current > hotStart {
                glow.stroke(
                    arc(from: hotStart, to: current, radius: progressRadius), with: .color(Theme.orange),
                    style: StrokeStyle(lineWidth: 10 * k, lineCap: .round, lineJoin: .round))
            }
        }
        var needle = Path()
        needle.move(to: point(at: current, radius: radius * 0.62))
        needle.addLine(to: point(at: current, radius: radius - 12 * k))
        var needleGlow = context
        needleGlow.addFilter(.shadow(color: accent.opacity(0.9), radius: 8 * k))
        needleGlow.stroke(needle, with: .color(accent), style: StrokeStyle(lineWidth: 5 * k, lineCap: .round))

        // Chiffres de l'échelle.
        let labelRadius: CGFloat = radius - 62 * k
        for value in stride(from: 0.0, through: maxSpeed, by: max(1, labelStep)) {
            let label = Text(Formatters.decimal(value, digits: 0))
                .font(.system(size: 25 * k, weight: .bold))
                .italic()
                .foregroundColor(Theme.textPrimary)
            context.draw(label, at: point(at: value, radius: labelRadius))
        }
    }
}

#Preview(traits: .landscapeLeft) {
    LandscapeSpeedometer(speed: 12, unit: "km/h", maxSpeed: 140, labelStep: 20, isAlert: false, signalBars: 3)
        .background(.black)
}
