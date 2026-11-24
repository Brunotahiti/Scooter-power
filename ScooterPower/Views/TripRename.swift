import SwiftData
import SwiftUI

/// Nommer un trajet (« Tour de l'île », « Col du matin ») ; un nom vide rend la date.
struct TripRenameModifier: ViewModifier {
    @Binding var trip: TripRecord?
    @State private var draft = ""
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .alert(L("Nommer le trajet"), isPresented: Binding(get: { trip != nil }, set: { if !$0 { trip = nil } })) {
                TextField(L("Par exemple : Tour de l'île"), text: $draft)
                    .textInputAutocapitalization(.sentences)
                Button(L("Enregistrer")) { save() }
                Button(L("Annuler"), role: .cancel) { trip = nil }
            } message: {
                Text(L("Laissez vide pour afficher la date du trajet."))
            }
            .onChange(of: trip?.persistentModelID) { _, _ in
                draft = trip?.name ?? ""
            }
    }

    private func save() {
        guard let trip else { return }
        let trimmed: String = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.name = trimmed.isEmpty ? nil : String(trimmed.prefix(60))
        try? modelContext.save()
        self.trip = nil
    }
}

extension View {
    /// Fenêtre « Nommer le trajet », ouverte quand `trip` reçoit un trajet.
    func tripRename(_ trip: Binding<TripRecord?>) -> some View {
        modifier(TripRenameModifier(trip: trip))
    }
}
