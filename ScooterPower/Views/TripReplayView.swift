import Combine
import MapKit
import SwiftUI
import ScooterCore

/// Un trajet à rejouer : le sien ou celui d'un ami.
struct ReplayTrack: Identifiable {
    let id: String
    let name: String
    let replay: TripReplay
    let color: Color
}

/// Revoir un trajet comme si on y était : vu du dessus, le scooter suit le
/// tracé à la vitesse réelle, s'oriente dans les virages, penche, freine.
/// En bas, le compteur et la vue de dos rejouent vitesse, poussée et
/// inclinaison. On peut ajouter le trajet d'un ami, rejoué en même temps.
struct TripReplayView: View {
    let main: ReplayTrack
    /// Trajets d'amis proposés en comparaison.
    var friends: [FriendTrip] = []

    @Environment(\.dismiss) private var dismiss
    @State private var time: TimeInterval = 0
    @State private var playing = false
    @State private var rate: Double = 4
    @State private var follow = true
    @State private var position: MapCameraPosition = .automatic
    @State private var mapHeading: Double = 0
    @State private var cameraHeading: Double?
    @State private var cameraDistance: Double = 450
    @State private var lastTick: Date?
    @State private var ghost: ReplayTrack?

    private static let rates: [Double] = [1, 2, 4, 10, 20]
    private let ticker = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    private let units: UnitSystem = AppSettings.shared.units

    private var duration: TimeInterval {
        max(main.replay.duration, ghost?.replay.duration ?? 0)
    }

    var body: some View {
        let frame: ReplayFrame? = main.replay.frame(at: time)
        let ghostFrame: ReplayFrame? = ghost?.replay.frame(at: time)
        return ZStack(alignment: .top) {
            map(frame: frame, ghostFrame: ghostFrame)
                .ignoresSafeArea()
            topBar
            VStack {
                Spacer()
                dashboard(frame: frame, ghostFrame: ghostFrame)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear { jump(to: 0) }
        .onReceive(ticker) { now in tick(now) }
        .statusBarHidden()
    }

    // MARK: - Carte

    private func map(frame: ReplayFrame?, ghostFrame: ReplayFrame?) -> some View {
        let route: [CLLocationCoordinate2D] = main.replay.route.map(\.mapCoordinate)
        let done: [CLLocationCoordinate2D] = traveled(main.replay, frame: frame)
        return Map(position: $position, interactionModes: [.pan, .zoom, .rotate]) {
            if let ghost {
                MapPolyline(coordinates: ghost.replay.route.map(\.mapCoordinate))
                    .stroke(ghost.color.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            MapPolyline(coordinates: route)
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            if done.count > 1 {
                MapPolyline(coordinates: done)
                    .stroke(main.color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            if let ghost, let ghostFrame {
                Annotation(ghost.name, coordinate: ghostFrame.coordinate.mapCoordinate, anchor: .center) {
                    TopViewScooter(frame: ghostFrame, rotation: ghostFrame.heading - mapHeading, tint: ghost.color)
                }
                .annotationTitles(.visible)
            }
            if let frame {
                Annotation("", coordinate: frame.coordinate.mapCoordinate, anchor: .center) {
                    TopViewScooter(frame: frame, rotation: frame.heading - mapHeading, tint: main.color)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .continuous) { context in
            mapHeading = context.camera.heading
            cameraDistance = context.camera.distance
        }
        .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in follow = false })
    }

    /// Partie déjà parcourue, jusqu'à la position actuelle.
    private func traveled(_ replay: TripReplay, frame: ReplayFrame?) -> [CLLocationCoordinate2D] {
        guard let frame else { return [] }
        let end: Int = min(frame.index, replay.route.count - 1)
        var points: [CLLocationCoordinate2D] = replay.route[0...end].map(\.mapCoordinate)
        points.append(frame.coordinate.mapCoordinate)
        return points
    }

    // MARK: - Lecture

    private func tick(_ now: Date) {
        defer { lastTick = now }
        guard let lastTick else { return }
        if playing {
            let dt: Double = min(0.2, now.timeIntervalSince(lastTick))
            time = min(duration, time + dt * rate)
            if time >= duration { playing = false }
        }
        if follow { updateCamera(animated: false) }
    }

    private func jump(to newTime: TimeInterval) {
        time = min(max(0, newTime), duration)
        cameraHeading = nil
        updateCamera(animated: false)
    }

    /// Caméra au-dessus du scooter, orientée dans son sens de marche ;
    /// le cap est lissé pour que la carte tourne en douceur dans les virages.
    private func updateCamera(animated: Bool) {
        guard let frame = main.replay.frame(at: time) else { return }
        let target: Double = frame.heading
        var heading: Double = cameraHeading ?? target
        var delta: Double = (target - heading).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        heading += delta * min(1, 0.12 * max(1, rate / 2))
        heading = (heading + 360).truncatingRemainder(dividingBy: 360)
        cameraHeading = heading
        let camera = MapCamera(
            centerCoordinate: frame.coordinate.mapCoordinate,
            distance: min(3000, max(150, cameraDistance)), heading: heading, pitch: 0)
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) { position = .camera(camera) }
        } else {
            position = .camera(camera)
        }
    }

    // MARK: - Haut de l'écran

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Fermer")
            VStack(alignment: .leading, spacing: 0) {
                Text(main.name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                Text(main.replay.isRecorded ? L("Revoir le trajet") : L("Vitesse moyenne (trajet ancien)"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            Spacer(minLength: 0)
            if !friends.isEmpty {
                ghostMenu
            }
            Button {
                follow = true
                cameraHeading = nil
                updateCamera(animated: true)
            } label: {
                Image(systemName: follow ? "location.north.line.fill" : "location.north.line")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(follow ? main.color : Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Suivre le scooter")
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var ghostMenu: some View {
        Menu {
            Button {
                ghost = nil
            } label: {
                if ghost == nil {
                    Label("Aucun", systemImage: "checkmark")
                } else {
                    Text("Aucun")
                }
            }
            ForEach(friends) { friend in
                Button {
                    if let shared = friend.shared {
                        ghost = ReplayTrack(
                            id: friend.persistentModelID.hashValue.description,
                            name: friend.displayName, replay: shared.replay, color: Theme.cyan)
                    }
                } label: {
                    Text(verbatim: friend.displayName + " · " + friend.title)
                }
            }
        } label: {
            Image(systemName: "person.2.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ghost == nil ? Theme.textPrimary : Theme.cyan)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("Comparer avec un ami")
    }

    // MARK: - Tableau de bord

    private func dashboard(frame: ReplayFrame?, ghostFrame: ReplayFrame?) -> some View {
        let speedKmh: Double = frame?.speedKmh ?? 0
        let speed: Double = units.speed(fromKmh: speedKmh)
        let fraction: Double = min(1, speed / units.speedometerMax)
        let accent: Color = SpeedBar.color(at: fraction)
        let acceleration: Double = frame?.acceleration ?? 0
        let lean: Double = frame?.leanDegrees ?? 0
        let accelText: String = Formatters.signed(acceleration, digits: 1) + " m/s²"
        let accelColor: Color = acceleration < -0.8 ? SpeedometerView.neonRed : Theme.orange
        let leanText: String = Formatters.decimal(abs(lean), digits: 0) + "°"
        let speedText: String = Formatters.decimal(speed, digits: 0)
        return VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                LiveScooter(
                    speedFraction: fraction, acceleration: acceleration,
                    leanDegrees: lean, accent: accent)
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(verbatim: speedText)
                            .font(.system(size: 50, weight: .black))
                            .italic()
                            .monospacedDigit()
                            .foregroundStyle(accent)
                            .shadow(color: accent.opacity(0.6), radius: 8)
                        Text(verbatim: units.speedUnit)
                            .font(.system(size: 17, weight: .heavy))
                            .italic()
                    }
                    HStack(spacing: 14) {
                        figure(icon: "bolt.fill", text: accelText, color: accelColor)
                        figure(icon: "angle", text: leanText, color: Theme.cyan)
                    }
                    if let ghost, let ghostFrame {
                        Text(verbatim: ghostText(ghost, ghostFrame))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ghost.color)
                            .lineLimit(1)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            controls
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(accent.opacity(0.7), lineWidth: 1.5))
                .shadow(color: accent.opacity(0.4), radius: 10))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private func ghostText(_ ghost: ReplayTrack, _ frame: ReplayFrame) -> String {
        let speed: String = Formatters.decimal(units.speed(fromKmh: frame.speedKmh), digits: 0)
        return ghost.name + " : " + speed + " " + units.speedUnit
    }

    private func figure(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(verbatim: text)
                .monospacedDigit()
        }
        .font(.system(size: 15, weight: .bold))
    }

    private var controls: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(get: { time }, set: { jump(to: $0) }),
                in: 0...max(1, duration))
                .tint(main.color)
                .accessibilityLabel("Position dans le trajet")
            HStack {
                Text(verbatim: Formatters.duration(time))
                Spacer()
                Button {
                    if time >= duration { jump(to: 0) }
                    playing.toggle()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 54, height: 44)
                        .background(main.color.opacity(0.25), in: Capsule())
                }
                .accessibilityLabel(playing ? L("Mettre en pause") : L("Lecture"))
                Menu {
                    ForEach(Self.rates, id: \.self) { value in
                        Button {
                            rate = value
                        } label: {
                            Text(verbatim: "×" + Formatters.decimal(value, digits: 0))
                        }
                    }
                } label: {
                    Text(verbatim: "×" + Formatters.decimal(rate, digits: 0))
                        .font(.system(size: 15, weight: .heavy))
                        .frame(width: 54, height: 44)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
                .accessibilityLabel("Vitesse de lecture")
                Spacer()
                Text(verbatim: Formatters.duration(duration))
            }
            .font(.system(size: 13, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
        }
    }
}

/// Le scooter vu du dessus, sur la carte : phare devant, traînée derrière
/// selon la vitesse, feu stop au freinage ; il s'affine et son ombre se
/// décale quand il penche.
struct TopViewScooter: View {
    let frame: ReplayFrame
    /// Rotation à l'écran, en degrés (cap moins orientation de la carte).
    let rotation: Double
    let tint: Color

    private static let width: CGFloat = 26
    private static let height: CGFloat = 52

    var body: some View {
        let lean: Double = min(45, max(-45, frame.leanDegrees))
        let leanFactor: CGFloat = CGFloat(abs(lean) / 45)
        let braking: CGFloat = CGFloat(min(1, max(0, -frame.acceleration / 4)))
        let speed: CGFloat = CGFloat(min(1, frame.speedKmh / 120))
        let halfHeight: CGFloat = Self.height * 0.5
        let beamOffset: CGFloat = -halfHeight - 20
        let trailLength: CGFloat = 12 + 60 * speed
        let trailOffset: CGFloat = halfHeight + 6 + 30 * speed
        let shadowShift: CGFloat = CGFloat(lean / 45 * 9)
        let squeeze: CGFloat = 1 - 0.3 * leanFactor
        let brakeBlur: CGFloat = 1 + 3 * braking
        let brakeGlow: CGFloat = 2 + 10 * braking
        let brakeOpacity: Double = 0.4 + 0.6 * Double(braking)
        let brakeOffset: CGFloat = halfHeight - 2
        return ZStack {
            // Faisceau du phare.
            LinearGradient(colors: [Color.white.opacity(0.35), Color.clear], startPoint: .bottom, endPoint: .top)
                .frame(width: 34, height: 46)
                .clipShape(BeamShape())
                .offset(y: beamOffset)
            // Traînée de vitesse.
            LinearGradient(colors: [tint.opacity(0.7), Color.clear], startPoint: .top, endPoint: .bottom)
                .frame(width: 10, height: trailLength)
                .clipShape(Capsule())
                .offset(y: trailOffset)
            // Ombre au sol, décalée du côté de l'inclinaison.
            Capsule()
                .fill(Color.black.opacity(0.5))
                .frame(width: Self.width * 0.8, height: Self.height * 0.9)
                .offset(x: shadowShift, y: 3)
                .blur(radius: 3)
            image
                .frame(width: Self.width, height: Self.height)
                .scaleEffect(x: squeeze, y: 1, anchor: .center)
                .shadow(color: tint.opacity(0.9), radius: 4)
            // Feu stop.
            Capsule()
                .fill(Color.red)
                .frame(width: 12, height: 4)
                .blur(radius: brakeBlur)
                .shadow(color: .red, radius: brakeGlow)
                .opacity(brakeOpacity)
                .offset(y: brakeOffset)
        }
        .rotationEffect(.degrees(rotation))
        .frame(width: 90, height: 90)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var image: some View {
        if let photo = UIImage(named: "ScooterTop") {
            Image(uiImage: photo).resizable().scaledToFit()
        } else {
            Image(systemName: "location.north.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
        }
    }
}

/// Cône de lumière qui s'élargit vers le haut.
private struct BeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
