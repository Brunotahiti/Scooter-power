import ActivityKit
import ScooterCore
import SwiftUI
import WidgetKit

/// Couleurs de l'app, redéfinies ici : l'extension ne voit pas le code de l'app.
private enum Palette {
    static let cyan = Color(red: 0x19 / 255.0, green: 0xD3 / 255.0, blue: 0xF3 / 255.0)
    static let secondary = Color(red: 0xA0 / 255.0, green: 0xA6 / 255.0, blue: 0xAD / 255.0)
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
                    ValueLabel(title: "Distance", value: context.state.distanceText)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "scooter")
                    .foregroundStyle(Palette.cyan)
            } compactTrailing: {
                Text(context.state.speedText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } minimal: {
                Text(context.state.speedText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
            .keylineTint(Palette.cyan)
        }
    }
}

private struct LockScreenTripView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            SpeedLabel(state: state, size: 44)
            Spacer(minLength: 8)
            ValueLabel(title: "Distance", value: state.distanceText)
            ValueLabel(title: state.isPaused ? "En pause" : "Durée", value: state.durationText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .foregroundStyle(Color.white)
    }
}

private struct SpeedLabel: View {
    let state: TripActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(state.speedText)
                .font(.system(size: size, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(state.isPaused ? Palette.secondary : Color.white)
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
