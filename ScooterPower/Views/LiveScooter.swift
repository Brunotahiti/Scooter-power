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

    /// `speed` : part de l'échelle de vitesse, de 0 à 1.
    func advance(to time: Double, speed: Double) -> Double {
        if let lastTime {
            let dt: Double = min(0.1, max(0, time - lastTime))
            // Immobile à l'arrêt ; le défilement s'accélère plus vite que la
            // vitesse (courbe en puissance 1,3) pour bien sentir la montée en régime.
            let s: Double = min(1, max(0, speed))
            let rate: Double = s < 0.01 ? 0 : 0.15 + 3.4 * pow(s, 1.3)
            phase += dt * rate
        }
        lastTime = time
        phase = phase.truncatingRemainder(dividingBy: 1000)
        return phase
    }
}

/// Route en perspective : asphalte, bords lumineux, deux lignes de voie en
/// pointillés de part et d'autre du scooter et balises sur les bords, qui
/// défilent vers nous ; elle s'incurve du côté de l'inclinaison.
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

    /// Géométrie de la route : `u` va de 0 (horizon) à 1 (bas de l'image).
    private struct Geometry {
        let horizon: CGFloat
        let depth: CGFloat
        let center: CGFloat
        let halfTop: CGFloat
        let halfBottom: CGFloat
        let curve: CGFloat

        func middle(_ u: CGFloat) -> CGFloat { center + curve * (1 - u) * (1 - u) }
        func half(_ u: CGFloat) -> CGFloat { halfTop + (halfBottom - halfTop) * u }
        func y(_ u: CGFloat) -> CGFloat { horizon + depth * u }
        func point(_ u: CGFloat, lane: CGFloat) -> CGPoint {
            CGPoint(x: middle(u) + half(u) * lane, y: y(u))
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, phase: Double) {
        let horizon: CGFloat = size.height * 0.16
        let g = Geometry(
            horizon: horizon, depth: size.height - horizon, center: size.width / 2,
            halfTop: size.width * 0.04, halfBottom: size.width * 0.66, curve: bend * size.width * 0.45)

        drawAsphalt(in: &context, g: g, size: size)
        drawEdges(in: &context, g: g)
        // Deux lignes de voie, de part et d'autre du scooter.
        for lane in [-0.56, 0.56] as [CGFloat] {
            drawDashes(in: &context, g: g, lane: lane, phase: phase)
        }
        drawPosts(in: &context, g: g, phase: phase)
        if speed > 0.45 {
            drawSpeedLines(in: &context, size: size, phase: phase)
        }
    }

    private func drawAsphalt(in context: inout GraphicsContext, g: Geometry, size: CGSize) {
        let steps = 24
        var road = Path()
        for step in 0...steps {
            let u: CGFloat = CGFloat(step) / CGFloat(steps)
            let p: CGPoint = g.point(u, lane: -1)
            if step == 0 { road.move(to: p) } else { road.addLine(to: p) }
        }
        for step in stride(from: steps, through: 0, by: -1) {
            road.addLine(to: g.point(CGFloat(step) / CGFloat(steps), lane: 1))
        }
        road.closeSubpath()
        context.fill(
            road,
            with: .linearGradient(
                Gradient(colors: [Color(white: 0.04), Color(white: 0.17)]),
                startPoint: CGPoint(x: 0, y: g.horizon), endPoint: CGPoint(x: 0, y: size.height)))
    }

    private func drawEdges(in context: inout GraphicsContext, g: Geometry) {
        var glow = context
        glow.addFilter(.shadow(color: accent, radius: 5))
        for lane in [-1, 1] as [CGFloat] {
            var line = Path()
            for step in 0...24 {
                let p: CGPoint = g.point(CGFloat(step) / 24, lane: lane)
                if step == 0 { line.move(to: p) } else { line.addLine(to: p) }
            }
            glow.stroke(line, with: .color(accent.opacity(0.9)), lineWidth: 2.5)
        }
    }

    /// Tirets régulièrement espacés en profondeur : petits à l'horizon,
    /// larges et lumineux en approchant.
    private func drawDashes(in context: inout GraphicsContext, g: Geometry, lane: CGFloat, phase: Double) {
        let count = 6
        var glow = context
        glow.addFilter(.shadow(color: Color.white.opacity(0.6), radius: 3))
        for index in 0..<count {
            var t: Double = (Double(index) / Double(count) + phase).truncatingRemainder(dividingBy: 1)
            if t < 0 { t += 1 }
            let t1: Double = min(1, t + 0.07)
            let u0: CGFloat = CGFloat(t * t)
            let u1: CGFloat = CGFloat(t1 * t1)
            let w0: CGFloat = 1 + 9 * u0
            let w1: CGFloat = 1 + 9 * u1
            let a: CGPoint = g.point(u0, lane: lane)
            let b: CGPoint = g.point(u1, lane: lane)
            var dash = Path()
            dash.move(to: CGPoint(x: a.x - w0 / 2, y: a.y))
            dash.addLine(to: CGPoint(x: a.x + w0 / 2, y: a.y))
            dash.addLine(to: CGPoint(x: b.x + w1 / 2, y: b.y))
            dash.addLine(to: CGPoint(x: b.x - w1 / 2, y: b.y))
            dash.closeSubpath()
            let opacity: Double = 0.35 + 0.65 * Double(u0)
            glow.fill(dash, with: .color(Color.white.opacity(opacity)))
        }
    }

    /// Balises sur les bords, en décalé des tirets : elles renforcent la sensation de vitesse.
    private func drawPosts(in context: inout GraphicsContext, g: Geometry, phase: Double) {
        let count = 5
        for index in 0..<count {
            var t: Double = (Double(index) / Double(count) + phase * 1.0 + 0.5 / Double(count))
                .truncatingRemainder(dividingBy: 1)
            if t < 0 { t += 1 }
            let u: CGFloat = CGFloat(t * t)
            let height: CGFloat = 4 + 26 * u
            let width: CGFloat = 1.5 + 4 * u
            for lane in [-1.08, 1.08] as [CGFloat] {
                let base: CGPoint = g.point(u, lane: lane)
                let post = Path(roundedRect: CGRect(x: base.x - width / 2, y: base.y - height, width: width, height: height),
                                cornerRadius: width / 2)
                context.fill(post, with: .color(accent.opacity(0.4 + 0.6 * Double(u))))
            }
        }
    }

    /// Traînées blanches sur les côtés, au-delà de la moitié de l'échelle.
    private func drawSpeedLines(in context: inout GraphicsContext, size: CGSize, phase: Double) {
        let strength: Double = min(1, (speed - 0.45) / 0.55)
        let count = 8
        for index in 0..<count {
            let seed: Double = Double(index) * 0.618
            var t: Double = (seed + phase * 1.6).truncatingRemainder(dividingBy: 1)
            if t < 0 { t += 1 }
            let side: CGFloat = index % 2 == 0 ? -1 : 1
            let x: CGFloat = size.width / 2 + side * size.width * (0.36 + 0.12 * CGFloat(seed.truncatingRemainder(dividingBy: 1)))
            let y: CGFloat = size.height * (0.2 + 0.8 * CGFloat(t))
            let length: CGFloat = size.height * (0.08 + 0.18 * CGFloat(strength))
            var line = Path()
            line.move(to: CGPoint(x: x, y: y))
            line.addLine(to: CGPoint(x: x + side * length * 0.25, y: y + length))
            context.stroke(
                line, with: .color(Color.white.opacity(0.35 * strength)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
}
