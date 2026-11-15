import SwiftUI

/// Scooter vu de face qui vit avec le trajet :
/// - il penche du même côté que vous ;
/// - en accélérant il grossit et se cabre, au freinage il recule et plonge ;
/// - plus la vitesse monte, plus il vibre et plus les traînées s'allongent ;
/// - le halo prend la couleur de la vitesse.
struct LiveScooter: View {
    /// Part de l'échelle de vitesse atteinte, de 0 à 1.
    let speedFraction: Double
    /// Accélération en m/s², signée.
    let acceleration: Double
    /// Inclinaison en degrés, positive vers la droite.
    let leanDegrees: Double
    /// Couleur du halo.
    let accent: Color

    private static let fullThrust: Double = 4
    private static let maxLean: Double = 45

    private var thrust: CGFloat {
        CGFloat(min(1, max(-1, acceleration / Self.fullThrust)))
    }

    private var lean: Double {
        min(Self.maxLean, max(-Self.maxLean, leanDegrees))
    }

    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = proxy.size
            let speed: CGFloat = CGFloat(min(1, max(0, speedFraction)))
            ZStack {
                halo(size: size, speed: speed)
                SpeedStreaks(strength: speed, color: accent)
                    .opacity(Double(0.25 + 0.75 * speed))
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: speed < 0.02)) { timeline in
                    let time: Double = timeline.date.timeIntervalSinceReferenceDate
                    let amplitude: CGFloat = 1.6 * speed * size.height / 120
                    ScooterBadge()
                        .padding(size.height * 0.04)
                        // Accélération : il avance vers nous et se cabre ; freinage : il recule et plonge.
                        .scaleEffect(1 + 0.12 * thrust)
                        .rotation3DEffect(.degrees(Double(-12 * thrust)), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                        .offset(y: -4 * thrust)
                        // Inclinaison autour du point de contact de la roue.
                        .rotationEffect(.degrees(lean), anchor: .bottom)
                        // Vibration de la route, plus forte avec la vitesse.
                        .offset(
                            x: amplitude * 0.5 * CGFloat(sin(time * 41)),
                            y: amplitude * CGFloat(sin(time * 53)))
                        .shadow(color: accent.opacity(0.4 + 0.5 * Double(abs(thrust))), radius: 6 + 10 * abs(thrust))
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: thrust)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: lean)
        .animation(.easeInOut(duration: 0.4), value: speedFraction)
        .accessibilityHidden(true)
    }

    /// Lueur ronde et floue derrière le scooter, sans bords visibles.
    private func halo(size: CGSize, speed: CGFloat) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [accent.opacity(0.75), accent.opacity(0.2), Color.clear],
                    center: .center, startRadius: 2, endRadius: size.height * 0.45))
            .frame(width: size.width * 1.3, height: size.height * 0.9)
            .offset(y: size.height * 0.08)
            .blur(radius: 6)
            .scaleEffect(1 + 0.15 * speed + 0.1 * max(0, thrust))
    }
}

/// Traînées de vitesse de part et d'autre du scooter.
private struct SpeedStreaks: View {
    let strength: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, size in
            let count = 5
            let length: CGFloat = size.width * (0.12 + 0.3 * strength)
            var glow = context
            glow.addFilter(.shadow(color: color, radius: 4))
            for index in 0..<count {
                let y: CGFloat = size.height * (0.3 + 0.12 * CGFloat(index))
                for side in [-1.0, 1.0] as [CGFloat] {
                    let start: CGFloat = size.width * 0.5 + side * size.width * 0.3
                    var path = Path()
                    path.move(to: CGPoint(x: start, y: y))
                    path.addLine(to: CGPoint(x: start + side * length * (1 - 0.15 * CGFloat(index % 3)), y: y + 6))
                    glow.stroke(
                        path, with: .color(color.opacity(0.85)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
