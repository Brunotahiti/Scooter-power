import SwiftUI
import ScooterCore

struct LeanCard: View {
    /// Degrés, positif vers la droite.
    let degrees: Double
    let text: String
    let side: LeanSide

    private var sideText: String {
        switch side {
        case .left: return "Vers la gauche"
        case .upright: return "Droit"
        case .right: return "Vers la droite"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inclinaison")
                        .font(.system(size: 18, weight: .bold))
                    Text(text)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    HStack(spacing: 6) {
                        Text(sideText)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textSecondary)
                        if side != .upright {
                            Image(systemName: side == .right ? "chevron.right" : "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.cyan)
                        }
                    }
                }
                .frame(width: 128, alignment: .leading)

                Rectangle()
                    .fill(Theme.cardBorder)
                    .frame(width: 1)
                    .padding(.vertical, 8)

                LeanGauge(degrees: degrees)
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
            }

            Text("En virage, l'angle affiché est inférieur à l'inclinaison réelle.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(12)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Inclinaison")
        .accessibilityValue("\(text), \(sideText)")
    }
}

/// Arc gradué de −45° à +45° avec la silhouette du scooter inclinée.
struct LeanGauge: View {
    let degrees: Double

    private static let range: Double = 45
    private static let labelHeight: CGFloat = 20

    /// Géométrie calculée une fois pour le dessin et pour la silhouette.
    private struct Metrics {
        let radius: CGFloat
        let pivot: CGPoint
        let scooterHeight: CGFloat

        init(size: CGSize) {
            let byWidth: CGFloat = size.width / 2 - 6
            let byHeight: CGFloat = size.height - LeanGauge.labelHeight - 6
            let fitted: CGFloat = min(byWidth, byHeight)
            radius = max(10, fitted)
            pivot = CGPoint(x: size.width / 2, y: size.height - LeanGauge.labelHeight)
            scooterHeight = radius * 0.62
        }

        /// Point à `angle` degrés de la verticale (positif à droite), à la distance `distance` du pivot.
        func point(at angle: Double, distance: CGFloat) -> CGPoint {
            let radians: Double = angle * Double.pi / 180
            let dx: CGFloat = distance * CGFloat(sin(radians))
            let dy: CGFloat = distance * CGFloat(cos(radians))
            return CGPoint(x: pivot.x + dx, y: pivot.y - dy)
        }
    }

    private var shown: Double {
        min(Self.range, max(-Self.range, degrees))
    }

    var body: some View {
        GeometryReader { proxy in
            content(metrics: Metrics(size: proxy.size))
        }
    }

    private func content(metrics: Metrics) -> some View {
        ZStack {
            Canvas { context, _ in
                draw(in: &context, metrics: metrics)
            }
            scooter(metrics: metrics)
            labels
        }
    }

    private func scooter(metrics: Metrics) -> some View {
        let height: CGFloat = metrics.scooterHeight
        let width: CGFloat = height * 0.62
        let centerY: CGFloat = metrics.pivot.y - height / 2
        return ScooterFrontShape()
            .stroke(Theme.textPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(shown), anchor: .bottom)
            .position(x: metrics.pivot.x, y: centerY)
            .animation(.easeOut(duration: 0.15), value: shown)
    }

    private var labels: some View {
        HStack {
            Text("Gauche")
            Spacer()
            Text("Droite")
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.textPrimary)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func draw(in context: inout GraphicsContext, metrics: Metrics) {
        let radius: CGFloat = metrics.radius
        let pivot: CGPoint = metrics.pivot
        let tickColor: Color = Theme.cyan.opacity(0.75)
        let dashed = StrokeStyle(lineWidth: 1, dash: [4, 4])

        // Graduations tous les 5°, plus longues tous les 15°.
        for step in -9...9 {
            let angle: Double = Double(step) * 5
            let length: CGFloat = step % 3 == 0 ? 11 : 7
            var tick = Path()
            tick.move(to: metrics.point(at: angle, distance: radius))
            tick.addLine(to: metrics.point(at: angle, distance: radius - length))
            context.stroke(tick, with: .color(tickColor), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }

        // Verticale de référence.
        var vertical = Path()
        vertical.move(to: pivot)
        vertical.addLine(to: metrics.point(at: 0, distance: radius - 14))
        context.stroke(vertical, with: .color(Theme.textPrimary.opacity(0.7)), style: dashed)

        // Sol.
        let halfGround: CGFloat = radius * 0.45
        var ground = Path()
        ground.move(to: CGPoint(x: pivot.x - halfGround, y: pivot.y))
        ground.addLine(to: CGPoint(x: pivot.x + halfGround, y: pivot.y))
        context.stroke(ground, with: .color(Theme.textPrimary), lineWidth: 1.5)

        // Axe du scooter.
        var axis = Path()
        axis.move(to: metrics.point(at: shown, distance: metrics.scooterHeight))
        axis.addLine(to: metrics.point(at: shown, distance: radius - 16))
        context.stroke(axis, with: .color(Theme.cyan.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

        // Repère de l'angle courant, avec halo.
        var marker = Path()
        marker.move(to: metrics.point(at: shown, distance: radius + 3))
        marker.addLine(to: metrics.point(at: shown, distance: radius - 14))
        var glow = context
        glow.addFilter(.shadow(color: Theme.cyan.opacity(0.9), radius: 5))
        glow.stroke(marker, with: .color(Theme.cyan), style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }
}

#Preview {
    LeanCard(degrees: 8, text: "8°", side: .right)
        .padding()
        .background(.black)
}
