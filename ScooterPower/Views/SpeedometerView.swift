import SwiftUI
import ScooterCore

/// Compteur en arc du mode portrait. `speed` est déjà dans l'unité affichée ;
/// `nil` affiche `--`. `scale` agrandit tout le compteur (1 = 190 pt d'arc).
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

    static let baseHeight: CGFloat = 190
    /// Hauteur de la silhouette de scooter, sous l'arc.
    private static let iconHeight: CGFloat = 34

    /// L'arc couvre 200° : de 190° (0, à gauche) à −10° (fin d'échelle, à droite).
    private static let startAngle: Double = 190
    private static let sweep: Double = 200
    /// Part de l'échelle à partir de laquelle commence la zone orange.
    private static let hotZone: Double = 100.0 / 140.0

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
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Canvas { context, size in
                    draw(in: &context, size: size)
                }
                readout
            }
            .frame(height: Self.baseHeight * scale)

            Image(systemName: "scooter")
                .font(.system(size: 30 * scale, weight: .regular))
                .foregroundStyle(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.9), radius: 8)
                .frame(height: Self.iconHeight * scale)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitesse actuelle")
        .accessibilityValue(speed == nil ? L("inconnue") : speedText + " " + unit)
    }

    private var readout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5 * scale) {
                Image(systemName: "location.north.fill")
                    .rotationEffect(.degrees(35))
                Text(verbatim: "GPS")
                signal
            }
            .font(.system(size: 15 * scale, weight: .bold))
            .foregroundStyle(signalBars == 0 ? Theme.textSecondary : Theme.cyan)

            Text(speedText)
                .font(.system(size: 76 * scale, weight: .black))
                .italic()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 76 * scale)
                .foregroundStyle(isAlert ? Theme.red : Theme.textPrimary)
                .shadow(color: (isAlert ? Theme.red : Theme.cyan).opacity(0.4), radius: 8)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: roundedSpeed)

            Text(verbatim: unit)
                .font(.system(size: 20 * scale, weight: .bold))
            Text("Vitesse actuelle")
                .font(.system(size: 14 * scale))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
    }

    /// Quatre barres de hauteur croissante ; celles au-delà du niveau sont éteintes.
    private var signal: some View {
        HStack(alignment: .bottom, spacing: 2 * scale) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < signalBars ? Theme.cyan : Theme.gaugeIdle)
                    .frame(width: 3.5 * scale, height: (5 + 3 * CGFloat(index)) * scale)
            }
        }
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

        func arc(from: Double, to: Double, radius r: CGFloat) -> Path {
            var path = Path()
            let steps: Int = max(2, Int(abs(to - from) / maxSpeed * 100))
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

        let current: Double = fraction * maxSpeed
        let hotStart: Double = maxSpeed * Self.hotZone
        let accent: Color = isAlert ? Theme.red : Theme.cyan

        // Graduations : fines toutes les 2 unités, longues toutes les 10. La
        // fin d'échelle est toujours colorée, de l'orange au rouge.
        let lastStep: Int = max(1, Int((maxSpeed / 2).rounded()))
        for step in 0...lastStep {
            let value: Double = Double(step) * 2
            let isMajor: Bool = step % 5 == 0
            let length: CGFloat = (isMajor ? 15 : 8) * k
            let width: CGFloat = (isMajor ? 2.5 : 1.2) * k
            let lit: Bool = value <= current && current > 0
            let color: Color
            if value >= hotStart {
                let heat: Double = (value - hotStart) / max(1, maxSpeed - hotStart)
                let base: Color = heat < 0.5 ? Theme.orange : Theme.red
                color = base.opacity(lit ? 1 : 0.6)
            } else {
                color = lit ? accent : Theme.gaugeIdle
            }
            var tick = Path()
            tick.move(to: point(at: value, radius: radius))
            tick.addLine(to: point(at: value, radius: radius - length))
            context.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        // Liseré extérieur : discret jusqu'à la zone orange, lumineux ensuite.
        let rimRadius: CGFloat = radius + 6 * k
        context.stroke(
            arc(from: 0, to: hotStart, radius: rimRadius), with: .color(Theme.cyan.opacity(0.35)),
            style: StrokeStyle(lineWidth: 2 * k, lineCap: .round))
        var hotGlow = context
        hotGlow.addFilter(.shadow(color: Theme.orange.opacity(0.8), radius: 6 * k))
        hotGlow.stroke(
            arc(from: hotStart, to: maxSpeed, radius: rimRadius),
            with: .linearGradient(
                Gradient(colors: [Theme.orange, Theme.red]),
                startPoint: point(at: hotStart, radius: rimRadius), endPoint: point(at: maxSpeed, radius: rimRadius)),
            style: StrokeStyle(lineWidth: 3 * k, lineCap: .round))

        // Arc parcouru et repère, avec halo.
        if current > 0 {
            let thick = StrokeStyle(lineWidth: 5 * k, lineCap: .round, lineJoin: .round)
            var glow = context
            glow.addFilter(.shadow(color: accent.opacity(0.9), radius: 7 * k))
            glow.stroke(arc(from: 0, to: min(current, hotStart), radius: rimRadius), with: .color(accent), style: thick)

            var marker = Path()
            marker.move(to: point(at: current, radius: radius + 10 * k))
            marker.addLine(to: point(at: current, radius: radius - 20 * k))
            let markerColor: Color = current > hotStart ? Theme.orange : accent
            glow.stroke(marker, with: .color(markerColor), style: thick)
        }

        // Chiffres.
        for value in stride(from: 0.0, through: maxSpeed, by: max(1, labelStep)) {
            let label = Text(Formatters.decimal(value, digits: 0))
                .font(.system(size: 14 * k, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            context.draw(label, at: point(at: value, radius: radius + 26 * k))
        }
    }
}

#Preview {
    SpeedometerView(speed: 82)
        .padding()
        .background(.black)
}
