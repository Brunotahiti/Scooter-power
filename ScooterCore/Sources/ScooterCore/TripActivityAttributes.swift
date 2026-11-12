// Compilé uniquement sur iOS : ActivityKit n'existe ni sur macOS ni sous Linux,
// où tournent les tests de ce package.
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Données de l'activité en direct d'un trajet, partagées par l'app et son
/// extension de widgets.
public struct TripActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        /// Vitesse sans unité, ou `--`.
        public var speedText: String
        public var distanceText: String
        public var durationText: String
        public var isPaused: Bool
        /// Accélération longitudinale en m/s², arrondie au dixième. Négative au freinage.
        public var acceleration: Double
        /// Inclinaison en degrés entiers. Positive vers la droite.
        public var leanDegrees: Double

        public init(speedText: String, distanceText: String, durationText: String, isPaused: Bool,
                    acceleration: Double, leanDegrees: Double) {
            self.speedText = speedText
            self.distanceText = distanceText
            self.durationText = durationText
            self.isPaused = isPaused
            self.acceleration = acceleration
            self.leanDegrees = leanDegrees
        }
    }

    public var startDate: Date

    public init(startDate: Date) {
        self.startDate = startDate
    }
}
#endif
