import ScooterCore

extension SpeedInterval {
    /// Plages affichées : en km/h ou en mph selon l'unité choisie dans les Réglages.
    /// Les deux séries sont toujours mesurées ; seul l'affichage change.
    @MainActor static var displayed: [SpeedInterval] {
        shown(for: AppSettings.shared.units)
    }
}
