import Charts
import SwiftUI
import ScooterCore

/// Résumé affiché à la fin d'un trajet.
struct SummaryView: View {
    let summary: TripSummary
    let route: [Coordinate]
    let date: Date?
    /// Records tous trajets confondus, trajet terminé compris.
    let recordTimes: [SpeedInterval: TimeInterval]
    /// Poussée des 30 dernières secondes du trajet.
    let accelerationHistory: [Double]
    let onDone: () -> Void

    @State private var share = ShareState()
    @State private var showMap = false
    @State private var showSettings = false
    private let settings = AppSettings.shared

    private var tripDate: Date { date ?? Date() }

    private var shareTitle: String {
        tripDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var dateLine: String {
        let day: String = tripDate.formatted(date: .abbreviated, time: .omitted)
        let time: String = tripDate.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(tripDate) {
            return L("Aujourd'hui") + " · " + day + " · " + time
        }
        return day + " · " + time
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    speedRow
                    timesCard
                    SummaryIntervalsCard(times: summary.bestTimes, records: recordTimes)
                    HStack(alignment: .top, spacing: 10) {
                        SummaryLeanCard(left: summary.maxLeanLeftDegrees, right: summary.maxLeanRightDegrees)
                        SummaryThrustCard(peak: summary.peakAcceleration, history: accelerationHistory)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            bottomBar
        }
        .foregroundStyle(Theme.textPrimary)
        .background(backdrop.ignoresSafeArea())
        .sharePresentation($share)
        .sheet(isPresented: $showMap) {
            MapSheet(route: route, showsUser: false)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .preferredColorScheme(.dark)
    }

    /// Fond sombre, avec un halo chaud en haut à la place d'une photo de route.
    private var backdrop: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Color(hex: 0x3A2210).opacity(0.85), Color.clear],
                center: UnitPoint(x: 0.85, y: 0), startRadius: 10, endRadius: 360)
            RadialGradient(
                colors: [Color(hex: 0x0B2A3A).opacity(0.9), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.3), startRadius: 10, endRadius: 320)
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                roundButton(icon: "chevron.left", label: L("Fermer"), action: onDone)
                Spacer()
                ShareMenu(summary: summary, route: route, title: shareTitle, date: date) { url in
                    share.receive(url)
                }
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Text("Résumé du trajet")
                .font(.system(size: 32, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 6)
            Label(dateLine, systemImage: "calendar")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 8)
    }

    private func roundButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 40)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Vitesses

    private var speedRow: some View {
        let units: UnitSystem = settings.units
        let top: String = Formatters.decimal(units.speed(fromKmh: summary.maxSpeedKmh), digits: 0)
        let average: Double = units.speed(fromKmh: summary.averageSpeedKmh)
        let peak: String = Formatters.signed(summary.peakAcceleration, digits: 1)
        return HStack(spacing: 0) {
            SummarySideTile(icon: "gauge.with.needle", title: L("Vitesse max."), value: top, unit: units.speedUnit)
            SummaryAverageGauge(speed: average, unit: units.speedUnit, maxSpeed: units.speedometerMax)
                .frame(width: 170, height: 150)
            SummarySideTile(icon: "bolt.fill", title: L("Pic d'accél."), value: peak, unit: "m/s²")
        }
    }

    private var timesCard: some View {
        let units: UnitSystem = settings.units
        let distance: String = Formatters.decimal(units.distance(fromMeters: summary.distanceMeters), digits: 1)
        return HStack(spacing: 0) {
            timeCell(icon: "mappin.and.ellipse", title: L("Distance"), value: distance, unit: units.distanceUnit)
            divider
            timeCell(icon: "stopwatch", title: L("Durée de roulage"), value: Formatters.duration(summary.movingDuration), unit: "")
            divider
            timeCell(icon: "stopwatch", title: L("Durée totale"), value: Formatters.duration(summary.totalDuration), unit: "")
        }
        .padding(.vertical, 12)
        .cardStyle()
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.cardBorder)
            .frame(width: 1, height: 54)
    }

    private func timeCell(icon: String, title: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.cyan)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(verbatim: unit)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value + " " + unit)
    }

    // MARK: - Bas de l'écran

    private var bottomBar: some View {
        HStack(spacing: 12) {
            squareButton(icon: "point.topleft.down.to.point.bottomright.curvepath", label: L("Carte")) {
                showMap = true
            }
            .disabled(route.count < 2)
            Button(action: onDone) {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                    Text("Nouveau trajet")
                        .font(.system(size: 21, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .foregroundStyle(Color.black)
                .background(
                    LinearGradient(colors: [Color(hex: 0x4FE3FF), Theme.cyan], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.cyan.opacity(0.5), radius: 10)
            }
            squareButton(icon: "gearshape", label: L("Réglages")) {
                showSettings = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func squareButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 58, height: 58)
                .cardStyle()
        }
        .accessibilityLabel(label)
    }
}

/// Tuile de part et d'autre du cadran : icône orange, titre, valeur.
private struct SummarySideTile: View {
    let icon: String
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.orange)
                .shadow(color: Theme.orange.opacity(0.6), radius: 5)
            Text(title)
                .font(.system(size: 13))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(verbatim: unit)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value + " " + unit)
    }
}

/// Cadran en arc de la vitesse moyenne.
private struct SummaryAverageGauge: View {
    /// Dans l'unité affichée.
    let speed: Double
    let unit: String
    let maxSpeed: Double

    private static let startAngle: Double = 200
    private static let sweep: Double = 220

    var body: some View {
        ZStack {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            VStack(spacing: 0) {
                Text(Formatters.decimal(speed, digits: 0))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text(verbatim: unit)
                    .font(.system(size: 14, weight: .semibold))
                Text("Vitesse moyenne")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .offset(y: 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitesse moyenne")
        .accessibilityValue(Formatters.decimal(speed, digits: 0) + " " + unit)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let radius: CGFloat = min(size.width / 2, size.height * 0.62) - 4
        guard radius > 20 else { return }
        let center = CGPoint(x: size.width / 2, y: radius + 4)
        let fraction: Double = min(1, max(0, speed / maxSpeed))

        func point(_ value: Double, _ r: CGFloat) -> CGPoint {
            let radians: Double = (Self.startAngle - Self.sweep * value) * Double.pi / 180
            return CGPoint(x: center.x + r * CGFloat(cos(radians)), y: center.y - r * CGFloat(sin(radians)))
        }

        func arc(to end: Double, radius r: CGFloat) -> Path {
            var path = Path()
            let steps = 60
            for index in 0...steps {
                let p: CGPoint = point(end * Double(index) / Double(steps), r)
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            return path
        }

        // Fond de l'arc, puis la partie parcourue.
        context.stroke(arc(to: 1, radius: radius - 6), with: .color(Theme.gaugeIdle.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 10, lineCap: .butt))
        if fraction > 0 {
            var glow = context
            glow.addFilter(.shadow(color: Theme.cyan.opacity(0.9), radius: 6))
            glow.stroke(arc(to: fraction, radius: radius - 6), with: .color(Theme.cyan),
                        style: StrokeStyle(lineWidth: 10, lineCap: .butt))
        }

        // Graduations et chiffres.
        for step in 0...12 {
            let value: Double = Double(step) / 12
            var tick = Path()
            tick.move(to: point(value, radius - 14))
            tick.addLine(to: point(value, radius - (step % 2 == 0 ? 24 : 19)))
            context.stroke(tick, with: .color(Theme.textPrimary.opacity(step % 2 == 0 ? 0.9 : 0.4)), lineWidth: 1.5)
        }
        let labelStep: Double = maxSpeed > 100 ? 20 : 10
        for value in stride(from: 0.0, through: maxSpeed, by: labelStep) {
            let label = Text(Formatters.decimal(value, digits: 0))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            context.draw(label, at: point(value / maxSpeed, radius - 34))
        }

        // Aiguille.
        var needle = Path()
        needle.move(to: point(fraction, radius - 46))
        needle.addLine(to: point(fraction, radius - 2))
        var glow = context
        glow.addFilter(.shadow(color: Theme.cyan.opacity(0.9), radius: 5))
        glow.stroke(needle, with: .color(Color.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
}

/// Temps d'accélération du trajet, chacun rapporté au record : 100 % signifie
/// que ce trajet a égalé ou battu le record.
private struct SummaryIntervalsCard: View {
    let times: [SpeedInterval: TimeInterval]
    let records: [SpeedInterval: TimeInterval]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Theme.cyan)
                Text("Accélérations du trajet")
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                Text("% du record")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(SpeedInterval.all.indices, id: \.self) { index in
                row(SpeedInterval.all[index])
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func row(_ interval: SpeedInterval) -> some View {
        let time: TimeInterval? = times[interval]
        let record: TimeInterval? = records[interval]
        var fraction: Double = 0
        if let time, time > 0, let record, record > 0 {
            fraction = min(1, record / time)
        }
        let timeText: String = time.map { Formatters.decimal($0, digits: 1) + " s" } ?? "--"
        let percent: String = time == nil ? "--" : Formatters.decimal(fraction * 100, digits: 0) + " %"
        let isRecord: Bool = time != nil && fraction >= 0.999
        return HStack(spacing: 10) {
            Text(verbatim: interval.label + " km/h")
                .font(.system(size: 14))
                .frame(width: 92, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.gaugeIdle.opacity(0.45))
                    Capsule()
                        .fill(isRecord ? Theme.orange : Theme.cyan)
                        .frame(width: proxy.size.width * CGFloat(fraction))
                        .shadow(color: (isRecord ? Theme.orange : Theme.cyan).opacity(0.7), radius: 4)
                }
            }
            .frame(height: 12)
            Text(verbatim: timeText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 46, alignment: .trailing)
            Text(verbatim: percent)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isRecord ? Theme.orange : Theme.textPrimary)
                .frame(width: 50, alignment: .trailing)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(interval.label + " km/h")
        .accessibilityValue(timeText + ", " + percent)
    }
}

/// Inclinaison maximale de chaque côté, sur un demi-cadran cyan et orange.
private struct SummaryLeanCard: View {
    let left: Double
    let right: Double

    private static let range: Double = 45

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "angle")
                    .foregroundStyle(Theme.cyan)
                Text("Inclinaison")
                    .font(.system(size: 16, weight: .bold))
            }
            HStack(alignment: .top) {
                side(L("Gauche"), left, Theme.cyan, alignment: .leading)
                Spacer()
                side(L("Droite"), right, Theme.orange, alignment: .trailing)
            }
            ZStack(alignment: .bottom) {
                Canvas { context, size in
                    draw(in: &context, size: size)
                }
                ScooterFrontShape()
                    .stroke(Theme.textPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 32, height: 52)
                    .shadow(color: Theme.cyan.opacity(0.6), radius: 4)
            }
            .frame(height: 64)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Inclinaison")
        .accessibilityValue(L("Gauche") + " " + Formatters.decimal(left, digits: 0) + "°, "
            + L("Droite") + " " + Formatters.decimal(right, digits: 0) + "°")
    }

    private func side(_ title: String, _ value: Double, _ color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(title)
                .font(.system(size: 13))
            Text(verbatim: Formatters.decimal(value, digits: 0) + "°")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let radius: CGFloat = min(size.width / 2, size.height) - 6
        let center = CGPoint(x: size.width / 2, y: size.height - 2)

        func arc(from: Double, to: Double) -> Path {
            var path = Path()
            let steps = 30
            for index in 0...steps {
                let angle: Double = from + (to - from) * Double(index) / Double(steps)
                let radians: Double = (90 - angle) * Double.pi / 180
                let p = CGPoint(x: center.x + radius * CGFloat(cos(radians)), y: center.y - radius * CGFloat(sin(radians)))
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            return path
        }

        let style = StrokeStyle(lineWidth: 8, lineCap: .round)
        context.stroke(arc(from: -90, to: 90), with: .color(Theme.gaugeIdle.opacity(0.45)), style: style)
        let leftEnd: Double = -90 * min(1, max(0, left) / Self.range)
        let rightEnd: Double = 90 * min(1, max(0, right) / Self.range)
        var glow = context
        glow.addFilter(.shadow(color: Theme.cyan.opacity(0.8), radius: 4))
        if left > 0 {
            glow.stroke(arc(from: 0, to: leftEnd), with: .color(Theme.cyan), style: style)
        }
        if right > 0 {
            glow.stroke(arc(from: 0, to: rightEnd), with: .color(Theme.orange), style: style)
        }
    }
}

/// Pic de poussée et courbe des 30 dernières secondes.
private struct SummaryThrustCard: View {
    let peak: Double
    let history: [Double]

    private struct Point: Identifiable {
        let id: Int
        let value: Double
    }

    var body: some View {
        var points: [Point] = []
        for index in history.indices {
            points.append(Point(id: index, value: max(0, history[index])))
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.needle")
                    .foregroundStyle(Theme.cyan)
                Text("Accélération")
                    .font(.system(size: 16, weight: .bold))
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Pic")
                    .font(.system(size: 13))
                Text(verbatim: Formatters.signed(peak, digits: 1))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(verbatim: "m/s²")
                    .font(.system(size: 12, weight: .semibold))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Chart(points) { point in
                AreaMark(x: .value("Temps", point.id), y: .value("Accélération", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.cyan.opacity(0.45), Theme.cyan.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Temps", point.id), y: .value("Accélération", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.cyan)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 52)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Accélération")
        .accessibilityValue(L("Pic : \(Formatters.signed(peak, digits: 1) + " m/s²")"))
    }
}
