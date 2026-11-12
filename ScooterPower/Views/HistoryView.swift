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
        let distance: String = Formatters.decimal(trip.distanceMeters / 1000, digits: 1) + " km"
        let duration: String = Formatters.duration(trip.totalDuration)
        let top: String = Formatters.decimal(trip.maxSpeedKmh, digits: 0) + " km/h max"
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
