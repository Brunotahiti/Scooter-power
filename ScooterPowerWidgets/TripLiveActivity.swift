import ActivityKit
import ScooterCore
import SwiftUI
import WidgetKit

/// Couleurs de l'app, redéfinies ici : l'extension ne voit pas le code de l'app.
private enum Palette {
    static let cyan = Color(red: 0x19 / 255.0, green: 0xD3 / 255.0, blue: 0xF3 / 255.0)
    static let orange = Color(red: 0xFF / 255.0, green: 0x8A / 255.0, blue: 0x1F / 255.0)
    static let red = Color(red: 0xE5 / 255.0, green: 0x48 / 255.0, blue: 0x4D / 255.0)
    static let secondary = Color(red: 0xA0 / 255.0, green: 0xA6 / 255.0, blue: 0xAD / 255.0)
    static let track = Color.white.opacity(0.14)
}

private typealias ActivityState = TripActivityAttributes.ContentState

/// Sens de la poussée, déduit des mêmes seuils que dans l'app.
private enum Thrust {
    case braking, steady, accelerating

    init(_ acceleration: Double) {
        switch AccelerationAnalyzer.level(for: acceleration) {
        case .brakingHard, .braking: self = .braking
        case .stable: self = .steady
        case .accelerating, .acceleratingHard: self = .accelerating
        }
    }

    var color: Color {
        switch self {
        case .braking: return Palette.red
        case .steady: return Palette.secondary
        case .accelerating: return Palette.orange
        }
    }

    var label: String {
        switch self {
        case .braking: return "Freinage"
        case .steady: return "Stable"
        case .accelerating: return "Accélération"
        }
    }

    var symbol: String {
        switch self {
        case .braking: return "chevron.backward.2"
        case .steady: return "equal"
        case .accelerating: return "chevron.forward.2"
        }
    }
}

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            LockScreenTripView(state: context.state)
                // Périmée : l'app ne met plus à jour (tuée ou plantée), les chiffres sont figés.
                .opacity(context.isStale ? 0.45 : 1)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SpeedLabel(state: context.state, size: 34)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ValueLabel(title: context.state.isPaused ? "En pause" : "Durée", value: context.state.durationText)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicsRow(state: context.state)
                        .padding(.horizontal, 6)
                        .padding(.top, 2)
                }
            } compactLeading: {
                CompactThrust(state: context.state)
            } compactTrailing: {
                Text(context.state.speedText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } minimal: {
                Text(context.state.speedText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
            .keylineTint(Thrust(context.state.acceleration).color)
        }
    }
}

// MARK: - Écran verrouillé

private struct LockScreenTripView: View {
    let state: ActivityState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                SpeedLabel(state: state, size: 44)
                Spacer(minLength: 8)
                ValueLabel(title: "Distance", value: state.distanceText)
                ValueLabel(title: state.isPaused ? "En pause" : "Durée", value: state.durationText)
            }
            DynamicsRow(state: state)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .foregroundStyle(Color.white)
    }
}

/// Poussée d'accélération à gauche, inclinaison à droite.
private struct DynamicsRow: View {
    let state: ActivityState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ThrustGauge(acceleration: state.acceleration)
            LeanDial(degrees: state.leanDegrees)
        }
    }
}

// MARK: - Poussée

/// Barre centrée sur zéro : elle se remplit en orange vers la droite quand on
/// accélère, en rouge vers la gauche quand on freine.
private struct ThrustGauge: View {
    let acceleration: Double

    private static let fullScale: Double = 4
    private static let barHeight: CGFloat = 10

    private var thrust: Thrust { Thrust(acceleration) }

    /// De −1 (freinage maximal) à +1 (accélération maximale).
    private var position: Double {
        min(1, max(-1, acceleration / Self.fullScale))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            header
            bar
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: thrust.symbol)
                .font(.system(size: 12, weight: .black))
            Text(thrust.label)
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 4)
            Text(Formatters.signed(acceleration, digits: 1) + " m/s²")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(thrust.color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var bar: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let half: CGFloat = width / 2
            let length: CGFloat = half * CGFloat(abs(position))
            let start: CGFloat = position < 0 ? half - length : half
            let knobX: CGFloat = half + half * CGFloat(position)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.track)
                fill(length: length)
                    .offset(x: start)
                centerMark
                    .offset(x: half - 1)
                knob
                    .offset(x: knobX - Self.barHeight)
            }
        }
        .frame(height: Self.barHeight)
    }

    private func fill(length: CGFloat) -> some View {
        let color: Color = thrust.color
        let gradient = LinearGradient(
            colors: [color.opacity(0.45), color],
            startPoint: position < 0 ? .trailing : .leading,
            endPoint: position < 0 ? .leading : .trailing)
        return Capsule()
            .fill(gradient)
            .frame(width: max(0, length))
            .shadow(color: color.opacity(0.8), radius: 5)
    }

    private var centerMark: some View {
        Rectangle()
            .fill(Color.white.opacity(0.55))
            .frame(width: 2)
    }

    private var knob: some View {
        let size: CGFloat = Self.barHeight * 2
        return Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(thrust.color, lineWidth: 3))
            .frame(width: size, height: size)
            .shadow(color: thrust.color.opacity(0.9), radius: 6)
    }
}

/// Chevrons colorés pour la vue compacte de la Dynamic Island.
private struct CompactThrust: View {
    let state: ActivityState

    var body: some View {
        let thrust = Thrust(state.acceleration)
        return Image(systemName: state.isPaused ? "pause.fill" : thrust.symbol)
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(state.isPaused ? Palette.secondary : thrust.color)
    }
}

// MARK: - Inclinaison

/// Petit cadran : un arc de −45° à +45° et une aiguille qui penche avec le scooter.
private struct LeanDial: View {
    let degrees: Double

    private static let radius: CGFloat = 24
    private static let range: Double = 45

    private var shown: Double {
        min(Self.range, max(-Self.range, degrees))
    }

    private var caption: String {
        let value: String = Formatters.decimal(abs(degrees), digits: 0) + "°"
        if degrees >= 1 { return value + " droite" }
        if degrees <= -1 { return value + " gauche" }
        return "Droit"
    }

    var body: some View {
        HStack(spacing: 8) {
            dial
            VStack(alignment: .leading, spacing: 1) {
                Text("Inclinaison")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
                Text(caption)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .lineLimit(1)
        }
        .fixedSize()
    }

    private var dial: some View {
        let diameter: CGFloat = Self.radius * 2
        return ZStack {
            // Le haut du cercle, de −45° à +45° autour de la verticale.
            Circle()
                .trim(from: 0.625, to: 0.875)
                .stroke(Palette.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 4, lineCap: .butt, dash: [2, 3]))
            needle
        }
        .frame(width: diameter, height: diameter)
        // Seule la moitié haute est utile.
        .frame(width: diameter, height: Self.radius + 4, alignment: .top)
        .clipped()
    }

    private var needle: some View {
        let length: CGFloat = Self.radius - 1
        return Capsule()
            .fill(Palette.cyan)
            .frame(width: 4, height: length)
            // Décalée vers le haut, l'aiguille pivote autour de son pied.
            .offset(y: -length / 2)
            .rotationEffect(.degrees(shown))
            .shadow(color: Palette.cyan.opacity(0.9), radius: 5)
    }
}

// MARK: - Éléments communs

private struct SpeedLabel: View {
    let state: ActivityState
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(state.speedText)
                .font(.system(size: size, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(state.isPaused ? Palette.secondary : Color.white)
                .contentTransition(.numericText())
            Text("km/h")
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.cyan)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct ValueLabel: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .lineLimit(1)
    }
}
