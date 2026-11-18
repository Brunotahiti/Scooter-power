import ScooterCore
import SwiftUI
import WidgetKit

/// Widget d'écran d'accueil : la semaine en kilomètres, le dernier trajet et
/// un bouton pour démarrer. Les textes viennent de l'app (sa langue, ses unités).
struct HomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScooterPowerHome", provider: HomeProvider()) { entry in
            HomeWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { HomeColors.background }
                .widgetURL(URL(string: "scooterpower://start"))
        }
        .configurationDisplayName(L("Scooter Power"))
        .description(L("Vos kilomètres de la semaine et un départ en un geste."))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct HomeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct HomeProvider: TimelineProvider {
    private var current: WidgetSnapshot {
        WidgetSnapshot.load(from: UserDefaults(suiteName: WidgetSnapshot.appGroup)) ?? .placeholder
    }

    func placeholder(in context: Context) -> HomeEntry {
        HomeEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeEntry) -> Void) {
        completion(HomeEntry(date: Date(), snapshot: context.isPreview ? .placeholder : current))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeEntry>) -> Void) {
        // L'app recharge le widget après chaque trajet ; à minuit, la semaine glisse.
        let midnight: Date = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(86_400)
        completion(Timeline(entries: [HomeEntry(date: Date(), snapshot: current)], policy: .after(midnight)))
    }
}

private enum HomeColors {
    static let background = Color(red: 0.05, green: 0.07, blue: 0.08)
    static let cyan = Color(red: 0x19 / 255.0, green: 0xD3 / 255.0, blue: 0xF3 / 255.0)
    static let secondary = Color(red: 0xA0 / 255.0, green: 0xA6 / 255.0, blue: 0xAD / 255.0)
}

struct HomeWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "scooter").font(.system(size: 14, weight: .bold))
                Text(snapshot.weekDistance.split(separator: " ").first.map(String.init) ?? "")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(snapshot.weekTitle, systemImage: "scooter")
                    .font(.caption2.weight(.semibold))
                Text(snapshot.weekDistance)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(snapshot.weekTrips).font(.caption2)
            }
        case .systemMedium:
            HStack(spacing: 16) {
                week
                VStack(alignment: .leading, spacing: 8) {
                    last
                    Spacer(minLength: 0)
                    startButton
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                week
                Spacer(minLength: 0)
                startButton
            }
        }
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "scooter")
                    .foregroundStyle(HomeColors.cyan)
                Text(snapshot.weekTitle)
                    .foregroundStyle(HomeColors.secondary)
            }
            .font(.caption.weight(.semibold))
            Text(snapshot.weekDistance)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(snapshot.weekTrips)
                .font(.caption2)
                .foregroundStyle(HomeColors.secondary)
            bars
        }
    }

    /// Une barre par jour sur les 7 derniers jours.
    private var bars: some View {
        let maximum: Double = max(snapshot.dailyDistances.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(snapshot.dailyDistances.enumerated()), id: \.offset) { index, value in
                Capsule()
                    .fill(index == snapshot.dailyDistances.count - 1 ? HomeColors.cyan : HomeColors.cyan.opacity(0.45))
                    .frame(width: 6, height: max(3, 22 * value / maximum))
            }
        }
        .frame(height: 22, alignment: .bottom)
    }

    @ViewBuilder
    private var last: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.lastTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(HomeColors.secondary)
            if let distance = snapshot.lastDistance {
                Text(distance)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let speed = snapshot.lastMaxSpeed {
                    Label(speed, systemImage: "gauge.with.dots.needle.67percent")
                        .font(.caption)
                        .foregroundStyle(HomeColors.cyan)
                }
                if let date = snapshot.lastDate {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(HomeColors.secondary)
                }
            } else {
                Text(snapshot.emptyTitle)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
        }
    }

    private var startButton: some View {
        HStack(spacing: 5) {
            Image(systemName: "play.fill")
            Text(snapshot.startTitle)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(HomeColors.cyan, in: Capsule())
    }
}
