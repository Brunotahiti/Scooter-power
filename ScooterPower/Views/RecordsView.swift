import Charts
import SwiftUI
import ScooterCore

/// Les records d'accélération : pour chaque plage, le record actuel, sa date,
/// le trajet qui l'a établi et sa progression au fil du temps.
struct RecordsView: View {
    let trips: [TripRecord]

    private var progression: [SpeedInterval: [RecordPoint]] {
        var entries: [RecordHistory.Trip] = []
        for trip in trips {
            entries.append(RecordHistory.Trip(date: trip.startDate, times: trip.summary.bestTimes))
        }
        return RecordHistory.progression(entries)
    }

    var body: some View {
        let all: [SpeedInterval: [RecordPoint]] = progression
        return ScrollView {
            VStack(spacing: 14) {
                ForEach(SpeedInterval.all.indices, id: \.self) { index in
                    RecordSection(
                        interval: SpeedInterval.all[index],
                        points: all[SpeedInterval.all[index]] ?? [],
                        trips: trips)
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// `RecordsView` présenté seul, avec sa propre barre de navigation.
struct RecordsSheet: View {
    let trips: [TripRecord]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RecordsView(trips: trips)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

private struct RecordSection: View {
    let interval: SpeedInterval
    /// Records successifs, du plus ancien au plus récent.
    let points: [RecordPoint]
    let trips: [TripRecord]

    private struct Row: Identifiable {
        let id: Int
        let point: RecordPoint
    }

    /// Du plus récent au plus ancien, pour la liste.
    private var rows: [Row] {
        var result: [Row] = []
        for index in points.indices.reversed() {
            result.append(Row(id: index, point: points[index]))
        }
        return result
    }

    private static func time(_ value: TimeInterval) -> String {
        Formatters.decimal(value, digits: 1) + " s"
    }

    private static func day(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if points.isEmpty {
                Text("Aucun temps mesuré pour l'instant.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                if points.count >= 2 {
                    chart
                }
                list
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(interval.label + " km/h")
                .font(.system(size: 18, weight: .bold))
            Spacer()
            if let current = points.last {
                HStack(spacing: 5) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                    Text(Self.time(current.time))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.cyan)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Le record ne peut que baisser : une courbe en escalier.
    private var chart: some View {
        Chart(rows) { row in
            LineMark(x: .value("Date", row.point.date), y: .value("Temps", row.point.time))
                .interpolationMethod(.stepEnd)
                .foregroundStyle(Theme.cyan)
            PointMark(x: .value("Date", row.point.date), y: .value("Temps", row.point.time))
                .foregroundStyle(Theme.cyan)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 110)
        .accessibilityLabel("Progression du record")
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                line(row)
            }
        }
    }

    @ViewBuilder
    private func line(_ row: Row) -> some View {
        let isCurrent: Bool = row.id == points.count - 1
        let content = HStack {
            Text(Self.day(row.point.date))
                .font(.system(size: 15))
                .foregroundStyle(isCurrent ? Theme.textPrimary : Theme.textSecondary)
            Spacer()
            Text(Self.time(row.point.time))
                .font(.system(size: 16, weight: isCurrent ? .bold : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isCurrent ? Theme.cyan : Theme.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 8)

        if trips.indices.contains(row.point.tripIndex) {
            NavigationLink {
                TripDetailView(trip: trips[row.point.tripIndex])
            } label: {
                content
            }
        } else {
            content
        }
    }
}
