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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inclinaison")
                        .font(.system(size: 18, weight: .bold))
                    Text(text)
                        .font(.system(size: 46, weight: .black, design: .rounded))
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
                    .frame(height: 104)
            }

            Text("En virage, l'angle affiché est inférieur à l'inclinaison réelle.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(14)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Inclinaison")
        .accessibilityValue("\(text), \(sideText)")
    }
}

/// Arc gradué de −45° à +45° avec la silhouette du scooter inclinée.
struct LeanGauge: View {
    let degrees: Double

    private static let range = 45.0

    private var shown: Double {
        min(Self.range, max(-Self.range, degrees))
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let labelHeight: CGFloat = 20
            let radius = max(10, min(size.width / 2 - 6, size.height - labelHeight - 6) )
            let pivot = CGPoint(x: size.width / 2, y: size.height - labelHeight)
            let scooterHeight = radius * 0.62

            ZStack {
                Canvas { context, _ in
                    func point(at angle: Double, radius r: CGFloat) -> CGPoint {
                        let radians = angle * .pi / 180
                        return CGPoint(x: pivot.x + r * CGFloat(sin(radians)), y: pivot.y - r * CGFloat(cos(radians)))
                    }

                    for step in -9...9 {
                        let angle = Double(step) * 5
                        var tick = Path()
                        tick.move(to: point(at: angle, radius: radius))
                        tick.addLine(to: point(at: angle, radius: radius - (step % 3 == 0 ? 11 : 7)))
                        context.stroke(
                            tick, with: .color(Theme.cyan.opacity(0.75)),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    }

                    // Verticale de référence.
                    var vertical = Path()
                    vertical.move(to: pivot)
                    vertical.addLine(to: point(at: 0, radius: radius - 14))
                    context.stroke(
                        vertical, with: .color(Theme.textPrimary.opacity(0.7)),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Sol.
                    var ground = Path()
                    ground.move(to: CGPoint(x: pivot.x - radius * 0.45, y: pivot.y))
                    ground.addLine(to: CGPoint(x: pivot.x + radius * 0.45, y: pivot.y))
                    context.stroke(ground, with: .color(Theme.textPrimary), lineWidth: 1.5)

                    // Axe du scooter et repère de l'angle courant.
                    var axis = Path()
                    axis.move(to: point(at: shown, radius: scooterHeight))
                    axis.addLine(to: point(at: shown, radius: radius - 16))
                    context.stroke(
                        axis, with: .color(Theme.cyan.opacity(0.8)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                    var marker = Path()
                    marker.move(to: point(at: shown, radius: radius + 3))
                    marker.addLine(to: point(at: shown, radius: radius - 14))
                    var glow = context
                    glow.addFilter(.shadow(color: Theme.cyan.opacity(0.9), radius: 5))
                    glow.stroke(marker, with: .color(Theme.cyan), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }

                ScooterFrontShape()
                    .stroke(Theme.textPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: scooterHeight * 0.62, height: scooterHeight)
                    .rotationEffect(.degrees(shown), anchor: .bottom)
                    .position(x: pivot.x, y: pivot.y - scooterHeight / 2)
                    .animation(.easeOut(duration: 0.15), value: shown)

                HStack {
                    Text("Gauche")
                    Spacer()
                    Text("Droite")
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

#Preview {
    LeanCard(degrees: 8, text: "8°", side: .right)
        .padding()
        .background(.black)
}
