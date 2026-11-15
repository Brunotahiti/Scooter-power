import SwiftUI
import ScooterCore

/// Compteur de vitesse : pastille GPS, grand panneau dont la couleur suit la
/// vitesse (du cyan au rouge), avec un
/// cadran autour de la vitesse et le scooter à droite, puis l'échelle et une
/// barre à segments du cyan au rouge avec un repère sur la vitesse actuelle.
/// `speed` est déjà dans l'unité affichée ; `nil` affiche `--`.
/// `scale` agrandit l'ensemble (1 en portrait).
struct SpeedometerView: View {
    let speed: Double?
    /// « km/h » ou « mph ».
    var unit: String = "km/h"
    /// Fin d'échelle, dans l'unité affichée.
    var maxSpeed: Double = 140
    /// Écart entre deux chiffres de l'échelle.
    var labelStep: Double = 20
    /// Vrai quand le seuil d'alerte est dépassé.
    var isAlert: Bool = false
    /// Qualité du signal GPS, de 0 à 4 barres.
    var signalBars: Int = 4
    /// Accélération en m/s², signée, pour animer le scooter.
    var acceleration: Double = 0
    /// Inclinaison en degrés, positive vers la droite, pour pencher le scooter.
    var leanDegrees: Double = 0
    var scale: CGFloat = 1

    /// Hauteur totale à l'échelle 1.
    static let baseHeight: CGFloat = 238

    static let neonRed = Color(hex: 0xFF2D2D)

    private var fraction: Double {
        min(1, max(0, (speed ?? 0) / maxSpeed))
    }

    private var speedText: String {
        speed.map { Formatters.decimal($0, digits: 0) } ?? "--"
    }

    /// Couleur du compteur : celle de la barre à la vitesse actuelle,
    /// du cyan au rouge ; rouge vif quand l'alerte est déclenchée.
    private var accent: Color {
        isAlert ? Self.neonRed : SpeedBar.color(at: fraction)
    }

    private var roundedSpeed: Int? {
        speed.map { Int($0.rounded()) }
    }

    var body: some View {
        VStack(spacing: 6 * scale) {
            gpsBadge
            panel
                .frame(height: 132 * scale)
            SpeedBar(fraction: fraction, maxSpeed: maxSpeed, labelStep: labelStep, scale: scale)
                .frame(height: 64 * scale)
        }
        .frame(height: Self.baseHeight * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitesse actuelle")
        .accessibilityValue(speed == nil ? L("inconnue") : speedText + " " + unit)
    }

    // MARK: - Pastille GPS

    private var gpsBadge: some View {
        GPSBadge(signalBars: signalBars, scale: scale)
    }

    // MARK: - Panneau principal

    private var panel: some View {
        let shape = HexagonFrame(tip: 30 * scale)
        let color: Color = accent
        let edge = LinearGradient(
            colors: [color, color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing)
        return GeometryReader { proxy in
            let height: CGFloat = proxy.size.height
            HStack(spacing: 0) {
                ZStack {
                    SpeedArc(fraction: fraction, color: color)
                    readout
                }
                .frame(maxWidth: .infinity)
                LiveScooter(
                    speedFraction: fraction, acceleration: acceleration,
                    leanDegrees: leanDegrees, accent: color)
                    .frame(width: height * 0.98 * 0.643, height: height * 0.98)
                    .padding(.trailing, 30 * scale)
            }
            .padding(.leading, 26 * scale)
        }
        .background(
            ZStack {
                Color.black.opacity(0.75)
                CarbonTexture()
                    .opacity(0.35)
                LinearGradient(
                    colors: [color.opacity(0.22), Color.clear, color.opacity(0.15)],
                    startPoint: .leading, endPoint: .trailing)
            }
            .clipShape(shape))
        .overlay(shape.stroke(edge, lineWidth: 2.5 * scale))
        .shadow(color: color.opacity(0.75), radius: 12 * scale)
        .animation(.easeInOut(duration: 0.5), value: fraction)
    }

    private var readout: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6 * scale) {
                Text(speedText)
                    .font(.system(size: 76 * scale, weight: .black))
                    .italic()
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: roundedSpeed)
                Text(verbatim: unit)
                    .font(.system(size: 22 * scale, weight: .heavy))
                    .italic()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(isAlert ? Self.neonRed : Theme.textPrimary)
            .shadow(color: accent.opacity(0.6), radius: 8)
            Text("Vitesse actuelle")
                .font(.system(size: 15 * scale, weight: .medium))
                .italic()
                .foregroundStyle(Theme.textPrimary.opacity(0.85))
        }
        .offset(y: 8 * scale)
    }
}

/// Pastille « GPS » à bords en pointe, avec la qualité du signal.
struct GPSBadge: View {
    /// Qualité du signal GPS, de 0 à 4 barres.
    let signalBars: Int
    var scale: CGFloat = 1

    var body: some View {
        let shape = HexagonFrame(tip: 12 * scale)
        return HStack(spacing: 7 * scale) {
            Image(systemName: "location.north.fill")
                .rotationEffect(.degrees(35))
                .foregroundStyle(Theme.cyan)
            Text(verbatim: "GPS")
                .italic()
                .foregroundStyle(Theme.textPrimary)
            signal
        }
        .font(.system(size: 16 * scale, weight: .heavy))
        .padding(.horizontal, 24 * scale)
        .frame(height: 30 * scale)
        .background(Color.black.opacity(0.7), in: shape)
        .overlay(
            shape.stroke(
                LinearGradient(
                    colors: [SpeedometerView.neonRed, Theme.cyan, SpeedometerView.neonRed],
                    startPoint: .leading, endPoint: .trailing),
                lineWidth: 1.5))
        .shadow(color: Theme.cyan.opacity(0.4), radius: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "GPS"))
        .accessibilityValue(Text(verbatim: "\(signalBars) / 4"))
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
}

/// Cadran en arc autour de la vitesse : graduations allumées jusqu'à la vitesse actuelle.
private struct SpeedArc: View {
    let fraction: Double
    let color: Color

    private static let startAngle: Double = 205
    private static let sweep: Double = 165
    private static let ticks = 36

    var body: some View {
        Canvas { context, size in
            let radius: CGFloat = min(size.width * 0.5, size.height * 0.95)
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5 + radius * 0.55)
            for index in 0...Self.ticks {
                let position: Double = Double(index) / Double(Self.ticks)
                let radians: Double = (Self.startAngle - Self.sweep * position) * Double.pi / 180
                let isMajor: Bool = index % 4 == 0
                let outer: CGFloat = radius
                let inner: CGFloat = radius - (isMajor ? 16 : 9)
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + outer * CGFloat(cos(radians)), y: center.y - outer * CGFloat(sin(radians))))
                tick.addLine(to: CGPoint(x: center.x + inner * CGFloat(cos(radians)), y: center.y - inner * CGFloat(sin(radians))))
                let lit: Bool = position <= fraction && fraction > 0
                context.stroke(
                    tick, with: .color(color.opacity(lit ? 1 : 0.35)),
                    style: StrokeStyle(lineWidth: isMajor ? 3 : 1.6, lineCap: .round))
            }
            // Arc continu, lumineux sur la partie parcourue.
            if fraction > 0 {
                var arc = Path()
                let steps = 60
                for step in 0...steps {
                    let position: Double = fraction * Double(step) / Double(steps)
                    let radians: Double = (Self.startAngle - Self.sweep * position) * Double.pi / 180
                    let point = CGPoint(
                        x: center.x + (radius + 4) * CGFloat(cos(radians)), y: center.y - (radius + 4) * CGFloat(sin(radians)))
                    if step == 0 { arc.move(to: point) } else { arc.addLine(to: point) }
                }
                var glow = context
                glow.addFilter(.shadow(color: color, radius: 6))
                glow.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }
    }
}

/// Fines rayures diagonales, façon fibre de carbone.
struct CarbonTexture: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 5
            }
            context.stroke(path, with: .color(Color.white.opacity(0.12)), lineWidth: 1)
        }
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

/// Échelle graduée et barre de vitesse à segments inclinés, du cyan au rouge,
/// avec un repère triangulaire sur la vitesse actuelle.
struct SpeedBar: View {
    /// Part de l'échelle atteinte, de 0 à 1.
    let fraction: Double
    let maxSpeed: Double
    let labelStep: Double
    let scale: CGFloat
    /// Chiffres au-dessus de la barre (portrait) ou en dessous (paysage).
    var labelsOnTop: Bool = true

    private static let segments = 40

    /// Dégradé de la barre : cyan, vert, jaune, orange puis rouge.
    private static let stops: [(position: Double, color: (r: Double, g: Double, b: Double))] = [
        (0.00, (0.10, 0.83, 0.95)),
        (0.45, (0.10, 0.83, 0.95)),
        (0.58, (0.18, 0.90, 0.35)),
        (0.66, (0.96, 0.90, 0.10)),
        (0.78, (1.00, 0.54, 0.12)),
        (0.90, (1.00, 0.18, 0.18)),
        (1.00, (0.95, 0.10, 0.12)),
    ]

    static func color(at position: Double) -> Color {
        let p: Double = min(1, max(0, position))
        for index in 1..<stops.count where p <= stops[index].position {
            let a = stops[index - 1]
            let b = stops[index]
            let t: Double = (p - a.position) / max(0.0001, b.position - a.position)
            return Color(
                red: a.color.r + (b.color.r - a.color.r) * t,
                green: a.color.g + (b.color.g - a.color.g) * t,
                blue: a.color.b + (b.color.b - a.color.b) * t)
        }
        return Color(red: 0.95, green: 0.10, blue: 0.12)
    }

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let k: CGFloat = scale
        let labelHeight: CGFloat = 30 * k
        let barHeight: CGFloat = size.height - labelHeight - (labelsOnTop ? 0 : 8 * k)
        guard barHeight > 8, size.width > 60 else { return }
        let barTop: CGFloat = labelsOnTop ? labelHeight : 8 * k
        let labelTop: CGFloat = labelsOnTop ? 0 : barTop + barHeight
        let tip: CGFloat = barHeight / 2
        let innerLeft: CGFloat = tip * 1.25
        let innerWidth: CGFloat = size.width - innerLeft * 2

        func x(at position: Double) -> CGFloat {
            innerLeft + innerWidth * CGFloat(position)
        }

        // Chiffres et repères de l'échelle.
        for value in stride(from: 0.0, through: maxSpeed, by: max(1, labelStep)) {
            let position: Double = value / maxSpeed
            let label = Text(Formatters.decimal(value, digits: 0))
                .font(.system(size: 15 * k, weight: .heavy))
                .italic()
                .foregroundColor(Theme.textPrimary)
            if labelsOnTop {
                context.draw(label, at: CGPoint(x: x(at: position), y: 9 * k))
                var tick = Path()
                tick.move(to: CGPoint(x: x(at: position), y: 19 * k))
                tick.addLine(to: CGPoint(x: x(at: position), y: labelHeight - 3 * k))
                context.stroke(tick, with: .color(Theme.textPrimary.opacity(0.9)), lineWidth: 2 * k)
            } else {
                context.draw(label, at: CGPoint(x: x(at: position), y: labelTop + labelHeight * 0.55))
            }
        }

        // Cadre de la barre : bleu à gauche, rouge à droite, lumineux.
        let frame = CGRect(x: 0, y: barTop, width: size.width, height: barHeight)
        let outline: Path = HexagonFrame(tip: tip).path(in: frame.insetBy(dx: 1.5 * k, dy: 1.5 * k))
        var glow = context
        glow.addFilter(.shadow(color: SpeedometerView.neonRed.opacity(0.6), radius: 7 * k))
        glow.stroke(
            outline,
            with: .linearGradient(
                Gradient(colors: [Theme.cyan, Theme.cyan, SpeedometerView.neonRed]),
                startPoint: CGPoint(x: 0, y: frame.midY), endPoint: CGPoint(x: size.width, y: frame.midY)),
            lineWidth: 2.2 * k)
        context.fill(outline, with: .color(Color.black.opacity(0.55)))

        // Segments inclinés, du cyan au rouge.
        let inset: CGFloat = 7 * k
        let top: CGFloat = barTop + inset
        let bottom: CGFloat = barTop + barHeight - inset
        let slant: CGFloat = (bottom - top) * 0.5
        let step: CGFloat = innerWidth / CGFloat(Self.segments)
        let width: CGFloat = step * 0.68
        var lit = context
        lit.addFilter(.shadow(color: Color.white.opacity(0.25), radius: 3 * k))
        for index in 0..<Self.segments {
            let position: Double = (Double(index) + 0.5) / Double(Self.segments)
            let left: CGFloat = innerLeft + step * CGFloat(index)
            var segment = Path()
            segment.move(to: CGPoint(x: left + slant, y: top))
            segment.addLine(to: CGPoint(x: left + slant + width, y: top))
            segment.addLine(to: CGPoint(x: left + width, y: bottom))
            segment.addLine(to: CGPoint(x: left, y: bottom))
            segment.closeSubpath()
            // Toute la barre est allumée ; le repère indique la vitesse actuelle.
            lit.fill(segment, with: .color(Self.color(at: position)))
        }

        // Repère : triangle au-dessus de la barre et trait lumineux à travers.
        let markerX: CGFloat = x(at: fraction)
        var triangle = Path()
        triangle.move(to: CGPoint(x: markerX - 8 * k, y: barTop - 6 * k))
        triangle.addLine(to: CGPoint(x: markerX + 8 * k, y: barTop - 6 * k))
        triangle.addLine(to: CGPoint(x: markerX, y: barTop + 6 * k))
        triangle.closeSubpath()
        var markerGlow = context
        markerGlow.addFilter(.shadow(color: Theme.cyan, radius: 6 * k))
        markerGlow.fill(triangle, with: .color(Color.white))
        var line = Path()
        line.move(to: CGPoint(x: markerX + slant * 0.5, y: barTop + 4 * k))
        line.addLine(to: CGPoint(x: markerX - slant * 0.5, y: barTop + barHeight - 4 * k))
        markerGlow.stroke(line, with: .color(Color.white.opacity(0.95)), style: StrokeStyle(lineWidth: 3 * k, lineCap: .round))
    }
}

#Preview {
    SpeedometerView(speed: 79)
        .padding()
        .background(.black)
}
