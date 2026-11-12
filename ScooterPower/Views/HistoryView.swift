import SwiftData
import SwiftUI
import ScooterCore

/// Liste des trajets enregistrés, du plus récent au plus ancien.
struct HistoryView: View {
    @Query(sort: \TripRecord.startDate, order: .reverse) private var trips: [TripRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Historique")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        // Il faut au moins deux trajets pour comparer.
                        if trips.count >= 2 {
                            NavigationLink("Comparer") {
                                TripComparisonView(trips: trips)
                            }
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        NavigationLink {
                            RecordsView(trips: trips)
                        } label: {
                            Label("Records", systemImage: "trophy.fill")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        if trips.isEmpty {
            ContentUnavailableView(
                "Aucun trajet",
                systemImage: "scooter",
                description: Text("Vos trajets terminés apparaîtront ici."))
        } else {
            List {
                ForEach(trips) { trip in
                    NavigationLink {
                        TripDetailView(trip: trip)
                    } label: {
                        HistoryRow(trip: trip)
                    }
                }
                .onDelete(perform: delete)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trips[index])
        }
    }
}

private struct HistoryRow: View {
    let trip: TripRecord

    private var details: String {
        let units: UnitSystem = AppSettings.shared.units
        let distance: String = Formatters.decimal(units.distance(fromMeters: trip.distanceMeters), digits: 1)
            + " " + units.distanceUnit
        let duration: String = Formatters.duration(trip.totalDuration)
        let speed: String = Formatters.decimal(units.speed(fromKmh: trip.maxSpeedKmh), digits: 0)
        let top: String = L("\(speed) \(units.speedUnit) max")
        return distance + " · " + duration + " · " + top
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(trip.title)
                .font(.system(size: 17, weight: .semibold))
            Text(details)
                .font(.system(size: 14))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 2)
    }
}
