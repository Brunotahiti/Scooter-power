import SwiftUI
import ScooterCore

/// Écran du trajet en paysage, façon tableau de bord rouge néon :
/// en haut l'historique, la pastille GPS, les commandes et le menu ;
/// au centre trois tuiles de chaque côté, le cadran rond et le scooter ;
/// en bas la barre de vitesse.
/// Carte et Photo restent réservées au portrait.
struct LandscapeTripView: View {
    let model: TripViewModel
    let onTogglePause: () -> Void
    let onMain: () -> Void
    let onOpenSettings: () -> Void
    let onHistory: () -> Void
    let onStats: () -> Void
    let onSettings: () -> Void

    private static let neonRed: Color = SpeedometerView.neonRed

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let height: CGFloat = proxy.size.height
            let topHeight: CGFloat = 40
            let barHeight: CGFloat = min(78, height * 0.2)
            let middleHeight: CGFloat = max(120, height - topHeight - barHeight - 12)
            let tileWidth: CGFloat = width * 0.22
            let gaugeSize: CGFloat = min(middleHeight, width * 0.34)
            VStack(spacing: 6) {
                topBar
                    .frame(height: topHeight)
                HStack(spacing: 0) {
                    tiles(leftTiles, mirrored: false)
                        .frame(width: tileWidth)
                    Spacer(minLength: 4)
                    center(gaugeSize: gaugeSize, height: middleHeight)
                    Spacer(minLength: 4)
                    tiles(rightTiles, mirrored: true)
                        .frame(width: tileWidth)
                }
                .frame(height: middleHeight)
                SpeedBar(
                    fraction: fraction, maxSpeed: model.speedometerMax,
                    labelStep: model.speedometerStep, scale: barHeight / 78, labelsOnTop: false)
                    .frame(height: barHeight)
                    .padding(.horizontal, width * 0.06)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(backdrop.ignoresSafeArea())
    }

    private var fraction: Double {
        min(1, max(0, (model.speedValue ?? 0) / model.speedometerMax))
    }

    // MARK: - Fond

    /// Noir carbone, avec des lueurs rouges sur les côtés.
    private var backdrop: some View {
        ZStack {
            Color.black
            CarbonTexture()
                .opacity(0.25)
            RadialGradient(
                colors: [Self.neonRed.opacity(0.28), Color.clear],
                center: UnitPoint(x: 0, y: 0.5), startRadius: 10, endRadius: 320)
            RadialGradient(
                colors: [Self.neonRed.opacity(0.28), Color.clear],
                center: UnitPoint(x: 1, y: 0.5), startRadius: 10, endRadius: 320)
            RadialGradient(
                colors: [Self.neonRed.opacity(0.2), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.45), startRadius: 20, endRadius: 260)
        }
    }

    // MARK: - Haut de l'écran

    private var topBar: some View {
        ZStack {
            if model.locationDenied {
                locationDenied
            } else {
                GPSBadge(signalBars: model.state == .idle ? 4 : model.gpsSignalBars, scale: 1.15)
            }
            HStack(spacing: 8) {
                Button(action: onHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 44, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Historique des trajets")
                statusPill
                Spacer(minLength: 0)
                controls
                menu
            }
        }
        .foregroundStyle(Theme.textPrimary)
    }

    @ViewBuilder
    private var statusPill: some View {
        switch model.state {
        case .recording:
            pill(text: L("Enregistrement"), color: Theme.red)
        case .paused:
            pill(text: L("En pause"), color: Theme.gaugeIdle)
        case .idle, .finished:
            EmptyView()
        }
    }

    private func pill(text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.22), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.8), lineWidth: 1))
        .fixedSize()
    }

    private var controls: some View {
        let isIdle: Bool = model.state == .idle
        let isActive: Bool = model.state == .recording || model.state == .paused
        return HStack(spacing: 8) {
            if isActive {
                Button(action: onTogglePause) {
                    Image(systemName: model.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.6), in: Circle())
                        .overlay(Circle().strokeBorder(Self.neonRed.opacity(0.8), lineWidth: 1.5))
                }
                .accessibilityLabel(model.state == .paused ? L("Reprendre") : L("Mettre en pause"))
            }
            Button(action: onMain) {
                Text(isIdle ? L("Démarrer") : L("Terminer"))
                    .font(.system(size: 15, weight: .heavy))
                    .italic()
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .foregroundStyle(isIdle ? Color.black : Color.white)
                    .background(mainFill(isIdle: isIdle), in: Capsule())
                    .shadow(color: (isIdle ? Theme.cyan : Self.neonRed).opacity(0.6), radius: 8)
            }
        }
    }

    private func mainFill(isIdle: Bool) -> LinearGradient {
        let colors: [Color] = isIdle
            ? [Color(hex: 0x4FE3FF), Theme.cyan]
            : [Color(hex: 0xFF4A3D), Color(hex: 0xC81E1E)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private var menu: some View {
        Menu {
            Button("Recalibrer l'inclinaison", systemImage: "scope") { model.recalibrate() }
                .disabled(model.state != .recording && model.state != .paused)
            Button("Statistiques", systemImage: "chart.bar.fill", action: onStats)
            Button("Réglages", systemImage: "gearshape", action: onSettings)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .heavy))
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Plus d'options")
    }

    private var locationDenied: some View {
        Button(action: onOpenSettings) {
            HStack(spacing: 6) {
                Image(systemName: "location.slash")
                Text("Position refusée · Ouvrir Réglages")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.orange)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Color.black.opacity(0.7), in: Capsule())
        }
        .frame(maxWidth: 260)
    }

    // MARK: - Centre : cadran et scooter

    private func center(gaugeSize: CGFloat, height: CGFloat) -> some View {
        let scooterHeight: CGFloat = height * 0.98
        let scooterWidth: CGFloat = scooterHeight * 0.643
        return HStack(spacing: -gaugeSize * 0.08) {
            RoundSpeedGauge(
                speed: model.speedValue,
                unit: model.speedUnit,
                maxSpeed: model.speedometerMax,
                labelStep: model.speedometerStep,
                isAlert: model.speedAlertActive)
                .frame(width: gaugeSize, height: gaugeSize)
                .zIndex(1)
            ScooterBadge()
                .frame(width: scooterWidth, height: scooterHeight)
                .background(
                    ZStack {
                        RadialGradient(
                            colors: [Self.neonRed.opacity(0.65), Self.neonRed.opacity(0.15), Color.clear],
                            center: UnitPoint(x: 0.5, y: 0.6), startRadius: 4, endRadius: scooterHeight * 0.6)
                        ScooterFlare()
                            .opacity(0.8)
                    })
        }
    }

    // MARK: - Tuiles

    private var leftTiles: [DashTile] {
        [
            DashTile(
                icon: "mountain.2", iconColor: Theme.textPrimary, title: L("Vitesse max."),
                text: model.maxSpeedText + " " + model.speedUnit),
            DashTile(icon: "road.lanes", iconColor: Theme.orange, title: L("Distance"), text: model.distanceText),
            DashTile(icon: "mountain.2", iconColor: Theme.textPrimary, title: L("Altitude"), text: model.altitudeText),
        ]
    }

    private var rightTiles: [DashTile] {
        [
            DashTile(
                icon: "gauge.with.needle", iconColor: Self.neonRed, title: L("Vitesse moy."),
                text: model.averageSpeedText + " " + model.speedUnit),
            DashTile(
                icon: "stopwatch", iconColor: Theme.textPrimary, title: L("Durée roulage"),
                text: model.movingDurationText),
            DashTile(
                icon: "bolt.fill", iconColor: Color(hex: 0xFFC21A), title: L("Pic d'accél."),
                text: model.peakText),
        ]
    }

    private func tiles(_ items: [DashTile], mirrored: Bool) -> some View {
        VStack(spacing: 8) {
            ForEach(items) { item in
                DashTileView(tile: item, mirrored: mirrored)
            }
        }
    }
}

// MARK: - Tuile de statistique

struct DashTile: Identifiable {
    let icon: String
    let iconColor: Color
    let title: String
    /// Valeur suivie de son unité, séparées par le dernier espace (« 0,8 km »).
    let text: String

    var id: String { title }

    var value: String {
        guard let space = text.lastIndex(of: " ") else { return text }
        return String(text[..<space])
    }

    var unit: String {
        guard let space = text.lastIndex(of: " ") else { return "" }
        return String(text[text.index(after: space)...])
    }
}

/// Tuile à coins coupés et bord rouge lumineux : icône, titre, valeur.
private struct DashTileView: View {
    let tile: DashTile
    /// Vrai pour les tuiles de droite : coins coupés en miroir.
    let mirrored: Bool

    var body: some View {
        let shape = ChamferFrame(cut: 14, mirrored: mirrored)
        let edge = LinearGradient(
            colors: [SpeedometerView.neonRed, SpeedometerView.neonRed.opacity(0.35), SpeedometerView.neonRed],
            startPoint: mirrored ? .trailing : .leading, endPoint: mirrored ? .leading : .trailing)
        return HStack(spacing: 10) {
            Image(systemName: tile.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(tile.iconColor)
                .shadow(color: tile.iconColor.opacity(0.6), radius: 4)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(tile.title)
                    .font(.system(size: 13, weight: .medium))
                    .italic()
                    .foregroundStyle(Theme.textPrimary.opacity(0.9))
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(verbatim: tile.value)
                        .font(.system(size: 24, weight: .heavy))
                        .italic()
                        .monospacedDigit()
                    if !tile.unit.isEmpty {
                        Text(verbatim: tile.unit)
                            .font(.system(size: 14, weight: .bold))
                            .italic()
                    }
                }
                .foregroundStyle(Theme.textPrimary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.8)
                LinearGradient(
                    colors: [SpeedometerView.neonRed.opacity(0.18), Color.clear],
                    startPoint: mirrored ? .trailing : .leading, endPoint: mirrored ? .leading : .trailing)
            }
            .clipShape(shape))
        .overlay(shape.stroke(edge, lineWidth: 2))
        .shadow(color: SpeedometerView.neonRed.opacity(0.55), radius: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tile.title)
        .accessibilityValue(tile.text)
    }
}

/// Rectangle aux coins haut droit et bas gauche coupés (ou l'inverse en miroir).
private struct ChamferFrame: Shape {
    let cut: CGFloat
    let mirrored: Bool

    func path(in rect: CGRect) -> Path {
        let c: CGFloat = min(cut, rect.height / 2)
        var path = Path()
        if mirrored {
            path.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
            path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Cadran rond

/// Cadran rond à bord rouge lumineux : graduations et chiffres sur un arc,
/// partie parcourue en rouge vif, aiguille, et la vitesse en grand au centre.
struct RoundSpeedGauge: View {
    let speed: Double?
    let unit: String
    let maxSpeed: Double
    let labelStep: Double
    let isAlert: Bool

    /// Angle du zéro et étendue de l'échelle, en degrés (sens trigonométrique).
    private static let startAngle: Double = 212
    private static let sweep: Double = 220

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
                face(side: side)
                Canvas { context, size in
                    drawScale(in: &context, size: size)
                }
                readout(side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitesse actuelle")
        .accessibilityValue(speed == nil ? L("inconnue") : speedText + " " + unit)
    }

    private func face(side: CGFloat) -> some View {
        let red: Color = SpeedometerView.neonRed
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x1A0505), Color.black, Color(hex: 0x2A0606)],
                        center: .center, startRadius: 0, endRadius: side * 0.5))
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: 0x8A8F96), Color.white, Color(hex: 0x50555C), Color(hex: 0x8A8F96)],
                        center: .center),
                    lineWidth: side * 0.025)
                .padding(side * 0.012)
            Circle()
                .stroke(red, lineWidth: side * 0.012)
                .padding(side * 0.04)
                .shadow(color: red, radius: side * 0.03)
        }
        .shadow(color: red.opacity(0.7), radius: side * 0.05)
    }

    private func point(_ center: CGPoint, radius: CGFloat, position: Double) -> CGPoint {
        let radians: Double = (Self.startAngle - Self.sweep * position) * Double.pi / 180
        return CGPoint(x: center.x + radius * CGFloat(cos(radians)), y: center.y - radius * CGFloat(sin(radians)))
    }

    private func drawScale(in context: inout GraphicsContext, size: CGSize) {
        let side: CGFloat = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius: CGFloat = side * 0.43
        let red: Color = SpeedometerView.neonRed

        // Bande rouge lumineuse sur la partie parcourue.
        if fraction > 0 {
            var band = Path()
            let steps = 80
            for step in 0...steps {
                let p: CGPoint = point(center, radius: radius - side * 0.02, position: fraction * Double(step) / Double(steps))
                if step == 0 { band.move(to: p) } else { band.addLine(to: p) }
            }
            var glow = context
            glow.addFilter(.shadow(color: red, radius: side * 0.03))
            glow.stroke(
                band, with: .color(red.opacity(0.85)),
                style: StrokeStyle(lineWidth: side * 0.05, lineCap: .butt))
        }

        // Graduations : une longue par chiffre, quatre petites entre deux.
        let step: Double = max(1, labelStep)
        let minorCount: Int = Int((maxSpeed / step).rounded()) * 5
        for index in 0...max(1, minorCount) {
            let position: Double = Double(index) / Double(max(1, minorCount))
            let isMajor: Bool = index % 5 == 0
            let outer: CGFloat = radius
            let inner: CGFloat = radius - side * (isMajor ? 0.07 : 0.04)
            var tick = Path()
            tick.move(to: point(center, radius: outer, position: position))
            tick.addLine(to: point(center, radius: inner, position: position))
            let lit: Bool = position <= fraction && fraction > 0
            context.stroke(
                tick, with: .color(lit ? Color.white : Color.white.opacity(0.75)),
                style: StrokeStyle(lineWidth: side * (isMajor ? 0.011 : 0.006), lineCap: .round))
        }

        // Chiffres de l'échelle.
        for value in stride(from: 0.0, through: maxSpeed, by: step) {
            let position: Double = value / maxSpeed
            let label = Text(Formatters.decimal(value, digits: 0))
                .font(.system(size: side * 0.068, weight: .heavy))
                .italic()
                .foregroundColor(Theme.textPrimary)
            context.draw(label, at: point(center, radius: radius - side * 0.13, position: position))
        }

        // Aiguille : trait lumineux du bord vers le centre.
        if fraction > 0 {
            var needle = Path()
            needle.move(to: point(center, radius: radius + side * 0.02, position: fraction))
            needle.addLine(to: point(center, radius: radius - side * 0.2, position: fraction))
            var glow = context
            glow.addFilter(.shadow(color: Color(hex: 0xFF8A3D), radius: side * 0.02))
            glow.stroke(
                needle, with: .color(Color(hex: 0xFFB070)),
                style: StrokeStyle(lineWidth: side * 0.014, lineCap: .round))
        }
    }

    private func readout(side: CGFloat) -> some View {
        let chrome = LinearGradient(
            colors: [Color.white, Color(hex: 0xC9CED6), Color(hex: 0x8A9099), Color.white],
            startPoint: .top, endPoint: .bottom)
        return VStack(spacing: -side * 0.02) {
            Text(verbatim: speedText)
                .font(.system(size: side * 0.27, weight: .black))
                .italic()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(isAlert ? AnyShapeStyle(SpeedometerView.neonRed) : AnyShapeStyle(chrome))
                .shadow(color: SpeedometerView.neonRed.opacity(0.9), radius: side * 0.02)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: speed.map { Int($0.rounded()) })
            Text(verbatim: unit)
                .font(.system(size: side * 0.09, weight: .heavy))
                .italic()
                .foregroundStyle(Theme.textPrimary)
            Text("Vitesse actuelle")
                .font(.system(size: side * 0.055, weight: .medium))
                .italic()
                .foregroundStyle(Theme.textPrimary.opacity(0.75))
                .padding(.top, side * 0.02)
        }
        .frame(width: side * 0.62)
        .offset(y: side * 0.06)
    }
}

/// Traînées rouges derrière le scooter, comme des éclats de lumière.
private struct ScooterFlare: View {
    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.62)
            var glow = context
            glow.addFilter(.blur(radius: 3))
            let rays: [(angle: Double, length: CGFloat)] = [
                (200, 0.55), (215, 0.42), (232, 0.5), (-20, 0.55), (-35, 0.42), (-52, 0.5), (160, 0.4), (20, 0.4),
            ]
            for ray in rays {
                let radians: Double = ray.angle * Double.pi / 180
                let length: CGFloat = size.height * ray.length
                var path = Path()
                path.move(to: origin)
                path.addLine(
                    to: CGPoint(
                        x: origin.x + length * CGFloat(cos(radians)), y: origin.y - length * CGFloat(sin(radians))))
                glow.stroke(
                    path, with: .color(SpeedometerView.neonRed.opacity(0.7)),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }
}
