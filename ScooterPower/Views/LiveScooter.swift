import SwiftUI

/// Scooter vu de dos, sur une route qui défile, comme si on le suivait :
/// - la route défile à la vitesse réelle et s'incurve dans les virages ;
/// - il penche du même côté que vous ;
/// - en accélérant il s'éloigne et s'accroupit, au freinage il revient vers
///   nous, plonge de l'avant et son feu stop s'allume ;
/// - il vibre plus fort avec la vitesse ;
/// - le halo prend la couleur de la vitesse.
struct LiveScooter: View {
    /// Part de l'échelle de vitesse atteinte, de 0 à 1.
    let speedFraction: Double
    /// Accélération en m/s², signée.
    let acceleration: Double
    /// Inclinaison en degrés, positive vers la droite.
    let leanDegrees: Double
    /// Couleur du halo et des bords de la route.
    let accent: Color

    static let rearImageName = "ScooterRear"
    /// Proportions de l'image de dos (largeur / hauteur).
    static let rearAspect: CGFloat = 487.0 / 900.0
    /// Position du feu arrière dans l'image, en fraction de sa hauteur.
    private static let tailLightY: CGFloat = 0.376

    private static let fullThrust: Double = 4
    private static let maxLean: Double = 45

    @State private var road = RoadClock()

    private var thrust: CGFloat {
        CGFloat(min(1, max(-1, acceleration / Self.fullThrust)))
    }

    private var braking: CGFloat { max(0, -thrust) }

    private var lean: Double {
        min(Self.maxLean, max(-Self.maxLean, leanDegrees))
    }

    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = proxy.size
            let speed: CGFloat = CGFloat(min(1, max(0, speedFraction)))
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let time: Double = timeline.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .bottom) {
                    RoadView(
                        clock: road, time: time, speed: Double(speed),
                        bend: CGFloat(lean / Self.maxLean), accent: accent)
                    halo(size: size, speed: speed)
                    scooter(size: size, speed: speed, time: time)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: thrust)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: lean)
        .accessibilityHidden(true)
    }

    // MARK: - Scooter

    @ViewBuilder
    private func scooter(size: CGSize, speed: CGFloat, time: Double) -> some View {
        let height: CGFloat = size.height * 0.84
        let width: CGFloat = height * Self.rearAspect
        let amplitude: CGFloat = 1.4 * speed * size.height / 120
        let push: CGFloat = thrust
        let scale: CGFloat = 1 - 0.07 * push
        let pitch: Angle = .degrees(Double(8 * push))
        let lift: CGFloat = -6 * max(0, push)
        let shakeX: CGFloat = amplitude * 0.5 * CGFloat(sin(time * 37))
        let shakeY: CGFloat = amplitude * CGFloat(sin(time * 51)) + lift
        let bottomGap: CGFloat = size.height * 0.02
        ZStack(alignment: .top) {
            rearImage
            tailLight(width: width, height: height)
        }
        .frame(width: width, height: height)
        // Accélération : il s'éloigne et s'accroupit ; freinage : il revient et plonge.
        .scaleEffect(scale, anchor: .bottom)
        .rotation3DEffect(pitch, axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
        // Inclinaison autour du point de contact du pneu.
        .rotationEffect(.degrees(lean), anchor: .bottom)
        // Vibration de la route.
        .offset(x: shakeX, y: shakeY)
        .shadow(color: Color.black.opacity(0.7), radius: 6, y: 4)
        .padding(.bottom, bottomGap)
    }

    @ViewBuilder
    private var rearImage: some View {
        if let photo = UIImage(named: Self.rearImageName) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
        } else {
            ScooterBadge()
        }
    }

    /// Feu arrière : faible lueur en roulant, rouge vif au freinage.
    private func tailLight(width: CGFloat, height: CGFloat) -> some View {
        let red = Color(red: 1, green: 0.08, blue: 0.08)
        let brake: CGFloat = braking
        let power: Double = 0.35 + 0.65 * Double(brake)
        let lightWidth: CGFloat = width * (0.42 + 0.25 * brake)
        let lightHeight: CGFloat = height * (0.045 + 0.04 * brake)
        let blurRadius: CGFloat = 3 + 8 * brake
        let glowRadius: CGFloat = 6 + 18 * brake
        let top: CGFloat = height * Self.tailLightY - height * 0.03
        let glow: Color = red.opacity(power)
        return Capsule()
            .fill(glow)
            .frame(width: lightWidth, height: lightHeight)
            .blur(radius: blurRadius)
            .shadow(color: glow, radius: glowRadius)
            .blendMode(.plusLighter)
            .offset(y: top)
    }

    /// Lueur ronde et floue derrière le scooter.
    private func halo(size: CGSize, speed: CGFloat) -> some View {
        let radius: CGFloat = size.height * 0.42
        let haloWidth: CGFloat = size.width * 1.1
        let haloHeight: CGFloat = size.height * 0.8
        let grow: CGFloat = 1 + 0.12 * speed
        let rise: CGFloat = -size.height * 0.1
        let gradient = RadialGradient(
            colors: [accent.opacity(0.55), accent.opacity(0.12), Color.clear],
            center: .center, startRadius: 2, endRadius: radius)
        return Ellipse()
            .fill(gradient)
            .frame(width: haloWidth, height: haloHeight)
            .blur(radius: 8)
            .scaleEffect(grow)
            .offset(y: rise)
    }
}

/// Avancement de la route, accumulé image par image pour rester fluide
/// quand la vitesse change.
final class RoadClock {
    var phase: Double = 0
    var lastTime: Double?

    func advance(to time: Double, speed: Double) -> Double {
        if let lastTime {
            let dt: Double = min(0.1, max(0, time - lastTime))
            // Jusqu'à environ 2,6 tirets par seconde à pleine échelle.
            phase += dt * (0.05 + 2.6 * speed)
        }
        lastTime = time
        phase = phase.truncatingRemainder(dividingBy: 1000)
        return phase
    }
}

/// Route en perspective : asphalte, bords lumineux et ligne centrale en
/// tirets qui défilent vers nous ; elle s'incurve du côté de l'inclinaison.
private struct RoadView: View {
    let clock: RoadClock
    let time: Double
    /// Vitesse, de 0 à 1.
    let speed: Double
    /// Courbure, de −1 (à gauche) à 1 (à droite).
    let bend: CGFloat
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let phase: Double = clock.advance(to: time, speed: speed)
            draw(in: &context, size: size, phase: phase)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, phase: Double) {
        let horizon: CGFloat = size.height * 0.18
        let bottom: CGFloat = size.height
        let depth: CGFloat = bottom - horizon
        let center: CGFloat = size.width / 2
        let halfBottom: CGFloat = size.width * 0.62
        let halfTop: CGFloat = size.width * 0.04
        let curve: CGFloat = bend * size.width * 0.45

        /// Abscisse du milieu de la route à la profondeur `u` (0 à l'horizon, 1 en bas).
        func middle(_ u: CGFloat) -> CGFloat { center + curve * (1 - u) * (1 - u) }
        func half(_ u: CGFloat) -> CGFloat { halfTop + (halfBottom - halfTop) * u }
        func y(_ u: CGFloat) -> CGFloat { horizon + depth * u }

        // Bords de la route, échantillonnés pour suivre la courbe.
        let steps = 24
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for step in 0...steps {
            let u: CGFloat = CGFloat(step) / CGFloat(steps)
            left.append(CGPoint(x: middle(u) - half(u), y: y(u)))
            right.append(CGPoint(x: middle(u) + half(u), y: y(u)))
        }
        var asphalt = Path()
        asphalt.addLines(left)
        asphalt.addLines(right.reversed())
        asphalt.closeSubpath()
        context.fill(
            asphalt,
            with: .linearGradient(
                Gradient(colors: [Color(white: 0.02), Color(white: 0.13)]),
                startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: bottom)))

        var edges = context
        edges.addFilter(.shadow(color: accent, radius: 4))
        for side in [left, right] {
            var line = Path()
            line.addLines(side)
            edges.stroke(line, with: .color(accent.opacity(0.85)), lineWidth: 2)
        }

        // Tirets centraux : régulièrement espacés en profondeur, ils
        // grossissent en approchant.
        let dashes = 7
        for index in 0..<dashes {
            var t: Double = (Double(index) / Double(dashes) + phase).truncatingRemainder(dividingBy: 1)
            if t < 0 { t += 1 }
            let u0: CGFloat = CGFloat(t * t)
            let u1: CGFloat = CGFloat(min(1, (t + 0.06) * (t + 0.06)))
            let w0: CGFloat = 1 + 5 * u0
            let w1: CGFloat = 1 + 5 * u1
            var dash = Path()
            dash.move(to: CGPoint(x: middle(u0) - w0 / 2, y: y(u0)))
            dash.addLine(to: CGPoint(x: middle(u0) + w0 / 2, y: y(u0)))
            dash.addLine(to: CGPoint(x: middle(u1) + w1 / 2, y: y(u1)))
            dash.addLine(to: CGPoint(x: middle(u1) - w1 / 2, y: y(u1)))
            dash.closeSubpath()
            context.fill(dash, with: .color(Color.white.opacity(0.25 + 0.6 * Double(u0))))
        }
    }
}
