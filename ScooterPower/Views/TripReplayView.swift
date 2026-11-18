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

/// Revoir un trajet comme une balade de groupe : carte de nuit, scooter vu
/// du dessus avec sa traînée lumineuse et son étiquette, une carte par
/// pilote avec sa vitesse. On peut ajouter jusqu'à 4 trajets d'amis, rejoués
/// en même temps, chacun avec sa couleur.
struct TripReplayView: View {
    let main: ReplayTrack
    /// Trajets d'amis proposés en comparaison.
    var friends: [FriendTrip] = []
    /// Autres pilotes affichés dès l'ouverture (balade de groupe enregistrée).
    var riders: [ReplayTrack] = []

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
    /// Trajets d'amis ajoutés, dans l'ordre de leur ajout.
    @State private var ghosts: [ReplayTrack] = []
    /// Fond de carte en photo satellite plutôt qu'en plan.
    @AppStorage(TripMapStyle.storageKey) private var satellite = false

    /// Pilote principal + 4 amis : 5, comme une balade de groupe.
    static let maxGhosts = GroupRoster.capacity - 1
    private static let rates: [Double] = [1, 2, 4, 10, 20]
    private static let red: Color = SpeedometerView.neonRed
    private let ticker = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    private let units: UnitSystem = AppSettings.shared.units

    /// Tous les trajets affichés, le principal en premier.
    private var tracks: [ReplayTrack] { [main] + ghosts }

    private var duration: TimeInterval {
        tracks.map(\.replay.duration).max() ?? 0
    }

    var body: some View {
        let frames: [ReplayFrame?] = tracks.map { $0.replay.frame(at: time) }
        return ZStack {
            backdrop.ignoresSafeArea()
            VStack(spacing: 8) {
                header
                map(frames: frames)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Self.red.opacity(0.8), lineWidth: 1.5))
                    .shadow(color: Self.red.opacity(0.5), radius: 8)
                    .overlay(alignment: .topTrailing) { mapButtons }
                    .padding(.horizontal, 8)
                riderCards(frames: frames)
                    .padding(.horizontal, 8)
                dashboard(frame: frames.first ?? nil)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if ghosts.isEmpty { ghosts = Array(riders.prefix(Self.maxGhosts)) }
            jump(to: 0)
        }
        .onReceive(ticker) { now in tick(now) }
    }

    private var backdrop: some View {
        ZStack {
            Color.black
            CarbonTexture()
                .opacity(0.18)
            RadialGradient(
                colors: [Self.red.opacity(0.22), Color.clear],
                center: UnitPoint(x: 0.5, y: 0), startRadius: 10, endRadius: 320)
            RadialGradient(
                colors: [Self.red.opacity(0.22), Color.clear],
                center: UnitPoint(x: 0.5, y: 1), startRadius: 10, endRadius: 300)
        }
    }

    // MARK: - En-tête

    private var subtitle: String {
        if ghosts.isEmpty { return main.name }
        if !riders.isEmpty { return L("Balade de groupe") + " · " + L("\(String(tracks.count)) pilotes") }
        return L("\(String(tracks.count)) pilotes") + " · " + main.name
    }

    private var header: some View {
        let shape = HexagonFrame(tip: 22)
        return HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(L("Fermer"))
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    NeonSlashes()
                    Text(L("Revoir le trajet"))
                        .font(.system(size: 26, weight: .black))
                        .italic()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(verbatim: subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .italic()
                    .foregroundStyle(Theme.textPrimary.opacity(0.8))
                    .lineLimit(1)
                if !main.replay.isRecorded {
                    Text(L("Vitesse moyenne (trajet ancien)"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.orange)
                }
            }
            Spacer(minLength: 0)
            if friends.isEmpty {
                Color.clear.frame(width: 36, height: 36)
            } else {
                friendsMenu
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.75), in: shape)
        .overlay(shape.stroke(Self.red, lineWidth: 1.8))
        .shadow(color: Self.red.opacity(0.7), radius: 10)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    /// Ajouter ou retirer des trajets d'amis, 4 au maximum.
    private var friendsMenu: some View {
        Menu {
            ForEach(friends) { friend in
                let id: String = friendID(friend)
                let added: Bool = ghosts.contains { $0.id == id }
                Button {
                    toggle(friend)
                } label: {
                    if added {
                        Label(friend.displayName + " · " + friend.title, systemImage: "checkmark")
                    } else {
                        Text(verbatim: friend.displayName + " · " + friend.title)
                    }
                }
                .disabled(!added && ghosts.count >= Self.maxGhosts)
            }
        } label: {
            Image(systemName: ghosts.isEmpty ? "person.2.badge.plus" : "person.3.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ghosts.isEmpty ? Theme.textPrimary : Theme.cyan)
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel(L("Comparer avec un ami"))
    }

    private func friendID(_ friend: FriendTrip) -> String {
        String(describing: friend.persistentModelID)
    }

    private func toggle(_ friend: FriendTrip) {
        let id: String = friendID(friend)
        if let index = ghosts.firstIndex(where: { $0.id == id }) {
            ghosts.remove(at: index)
        } else if ghosts.count < Self.maxGhosts, let shared = friend.shared {
            ghosts.append(ReplayTrack(id: id, name: friend.displayName, replay: shared.replay, color: .clear))
        }
        // Couleurs libres, dans l'ordre de la balade, pour les trajets d'amis ajoutés.
        var used: [Color] = [main.color] + riders.map(\.color)
        ghosts = ghosts.map { track in
            if track.color != .clear { return track }
            let color: Color = GroupRideView.colors.first { !used.contains($0) } ?? Theme.cyan
            used.append(color)
            return ReplayTrack(id: track.id, name: track.name, replay: track.replay, color: color)
        }
    }

    // MARK: - Carte

    private func map(frames: [ReplayFrame?]) -> some View {
        Map(position: $position, interactionModes: [.pan, .zoom, .rotate]) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                ReplayMapContent.route(track, frame: frames[index], isMain: index == 0)
            }
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                if let frame = frames[index] {
                    Annotation("", coordinate: frame.coordinate.mapCoordinate, anchor: .bottom) {
                        ReplayMarker(name: markerName(index: index, track: track), color: track.color,
                                     frame: frame, rotation: frame.heading - mapHeading)
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(TripMapStyle.style(satellite: satellite))
        .onMapCameraChange(frequency: .continuous) { context in
            mapHeading = context.camera.heading
            cameraDistance = context.camera.distance
        }
        .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in follow = false })
    }

    private func markerName(index: Int, track: ReplayTrack) -> String {
        index == 0 && main.id == "mine" ? L("Moi") : track.name
    }

    private var mapButtons: some View {
        VStack(spacing: 8) {
            SatelliteToggle(satellite: $satellite)
            Button {
                follow = true
                cameraHeading = nil
                updateCamera(animated: true)
            } label: {
                Image(systemName: follow ? "location.north.line.fill" : "location.north.line")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(follow ? main.color : Theme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.7), in: Circle())
            }
            .accessibilityLabel(L("Suivre le scooter"))
            Button {
                follow = false
                withAnimation(.easeInOut(duration: 0.5)) { position = .automatic }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.7), in: Circle())
            }
            .accessibilityLabel(L("Voir tout le trajet"))
        }
        .padding(10)
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

    /// Caméra au-dessus du scooter principal, orientée dans son sens de marche ;
    /// le cap est lissé pour que la carte tourne en douceur dans les virages.
    private func updateCamera(animated: Bool) {
        guard let frame = main.replay.frame(at: time) else { return }
        let target: Double = frame.heading
        var heading: Double = cameraHeading ?? target
        var delta: Double = (target - heading).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let smoothing: Double = min(1, 0.12 * max(1, rate / 2))
        heading += delta * smoothing
        heading = (heading + 360).truncatingRemainder(dividingBy: 360)
        cameraHeading = heading
        let distance: Double = min(3000, max(150, cameraDistance))
        let camera = MapCamera(
            centerCoordinate: frame.coordinate.mapCoordinate, distance: distance, heading: heading, pitch: 0)
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) { position = .camera(camera) }
        } else {
            position = .camera(camera)
        }
    }

    // MARK: - Cartes des pilotes

    private func riderCards(frames: [ReplayFrame?]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                ReplayRiderCard(
                    name: markerName(index: index, track: track), color: track.color,
                    speedKmh: frames[index]?.speedKmh, finished: time >= track.replay.duration && time > 0)
            }
        }
        .frame(height: 70)
    }

    // MARK: - Tableau de bord

    private func dashboard(frame: ReplayFrame?) -> some View {
        let speedKmh: Double = frame?.speedKmh ?? 0
        let speed: Double = units.speed(fromKmh: speedKmh)
        let fraction: Double = min(1, speed / units.speedometerMax)
        let accent: Color = SpeedBar.color(at: fraction)
        let acceleration: Double = frame?.acceleration ?? 0
        let lean: Double = frame?.leanDegrees ?? 0
        let accelText: String = Formatters.signed(acceleration, digits: 1) + " m/s²"
        let accelColor: Color = acceleration < -0.8 ? Self.red : Theme.orange
        let leanText: String = Formatters.decimal(abs(lean), digits: 0) + "°"
        let shape = HexagonFrame(tip: 18)
        return VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                LiveScooter(speedFraction: fraction, acceleration: acceleration, leanDegrees: lean, accent: accent)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    figure(icon: "bolt.fill", title: L("Poussée"), text: accelText, color: accelColor)
                    figure(icon: "angle", title: L("Inclinaison"), text: leanText, color: Theme.cyan)
                }
                Spacer(minLength: 0)
            }
            controls
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8), in: shape)
        .overlay(shape.stroke(accent.opacity(0.8), lineWidth: 1.5))
        .shadow(color: accent.opacity(0.4), radius: 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private func figure(icon: String, title: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(verbatim: title)
                .font(.system(size: 13, weight: .medium))
                .italic()
                .foregroundStyle(Theme.textSecondary)
            Text(verbatim: text)
                .font(.system(size: 17, weight: .heavy))
                .italic()
                .monospacedDigit()
        }
        .font(.system(size: 15, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var controls: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(get: { time }, set: { jump(to: $0) }),
                in: 0...max(1, duration))
                .tint(main.color)
                .accessibilityLabel(L("Position dans le trajet"))
            HStack {
                Text(verbatim: Formatters.duration(time))
                Spacer()
                Button {
                    if time >= duration { jump(to: 0) }
                    playing.toggle()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 64, height: 42)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0xFF4A3D), Color(hex: 0xA80F0F)],
                                startPoint: .top, endPoint: .bottom),
                            in: Capsule())
                        .shadow(color: Self.red.opacity(0.7), radius: 8)
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
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 54, height: 42)
                        .background(Color(hex: 0x1A1D21), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                .accessibilityLabel(L("Vitesse de lecture"))
                Spacer()
                Text(verbatim: Formatters.duration(duration))
            }
            .font(.system(size: 13, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Carte : tracés et marqueurs

enum ReplayMapContent {
    /// Tracé complet en pointillé discret, partie parcourue en traînée lumineuse.
    @MainActor @MapContentBuilder
    static func route(_ track: ReplayTrack, frame: ReplayFrame?, isMain: Bool) -> some MapContent {
        let full: [CLLocationCoordinate2D] = track.replay.route.map(\.mapCoordinate)
        let done: [CLLocationCoordinate2D] = traveled(track.replay, frame: frame)
        let width: CGFloat = isMain ? 4.5 : 3.5
        MapPolyline(coordinates: full)
            .stroke(track.color.opacity(0.25), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        if done.count > 1 {
            MapPolyline(coordinates: done)
                .stroke(track.color.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: done)
                .stroke(track.color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }

    /// Partie déjà parcourue, jusqu'à la position actuelle.
    static func traveled(_ replay: TripReplay, frame: ReplayFrame?) -> [CLLocationCoordinate2D] {
        guard let frame, !replay.route.isEmpty else { return [] }
        let end: Int = min(frame.index, replay.route.count - 1)
        var points: [CLLocationCoordinate2D] = replay.route[0...end].map(\.mapCoordinate)
        points.append(frame.coordinate.mapCoordinate)
        return points
    }
}

/// Étiquette néon du pilote au-dessus de son scooter vu du dessus.
private struct ReplayMarker: View {
    let name: String
    let color: Color
    let frame: ReplayFrame
    let rotation: Double

    var body: some View {
        VStack(spacing: 0) {
            NameTag(name: name, color: color)
            TopViewScooter(frame: frame, rotation: rotation, tint: color)
                .scaleEffect(0.85)
                .frame(width: 66, height: 66)
        }
    }
}

/// Carte d'un pilote : pastille de couleur, nom et vitesse du moment.
private struct ReplayRiderCard: View {
    let name: String
    let color: Color
    let speedKmh: Double?
    let finished: Bool

    private var units: UnitSystem { AppSettings.shared.units }

    var body: some View {
        let shape = HexagonFrame(tip: 9)
        let speed: String = speedKmh.map { Formatters.decimal(units.speed(fromKmh: $0), digits: 0) } ?? "--"
        return VStack(spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .shadow(color: color, radius: 3)
                Text(verbatim: name)
                    .font(.system(size: 12, weight: .bold))
                    .italic()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Rectangle()
                .fill(color.opacity(0.35))
                .frame(height: 1)
                .padding(.horizontal, 6)
            if finished {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 18, weight: .bold))
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: speed)
                        .font(.system(size: 22, weight: .black))
                        .italic()
                        .monospacedDigit()
                    Text(verbatim: units.speedUnit)
                        .font(.system(size: 9, weight: .bold))
                        .italic()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 6)
        .frame(maxWidth: 140, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.8), in: shape)
        .overlay(shape.stroke(SpeedometerView.neonRed.opacity(0.9), lineWidth: 1.4))
        .shadow(color: SpeedometerView.neonRed.opacity(0.45), radius: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(finished ? L("Arrivé") : speed + " " + units.speedUnit)
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
