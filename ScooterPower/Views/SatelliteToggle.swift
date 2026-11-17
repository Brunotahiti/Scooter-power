import MapKit
import SwiftUI

/// Fond de carte des écrans de trajet : plan sombre ou photo satellite.
/// Le choix est mémorisé d'un écran et d'un lancement à l'autre.
enum TripMapStyle {
    static let storageKey = "tripMapSatellite"

    static func style(satellite: Bool) -> MapStyle {
        satellite
            ? .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll)
            : .standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll)
    }
}

/// Bouton rond qui bascule entre plan et photo satellite.
struct SatelliteToggle: View {
    @Binding var satellite: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) { satellite.toggle() }
        } label: {
            Image(systemName: satellite ? "map.fill" : "globe.europe.africa.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(satellite ? Theme.cyan : Theme.textPrimary)
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.7), in: Circle())
        }
        .accessibilityLabel(satellite ? L("Afficher le plan") : L("Afficher la photo satellite"))
    }
}
