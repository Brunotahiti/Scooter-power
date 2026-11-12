import Foundation
import Observation
import ScooterCore

/// Réglages de l'utilisateur, conservés d'un lancement à l'autre.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// Bornes du seuil d'alerte, en km/h.
    static let speedAlertRange: ClosedRange<Double> = 20...250
    /// Pas de réglage du seuil, dans l'unité affichée.
    static let speedAlertStep: Double = 5

    private enum Key {
        static let units = "units"
        static let speedAlertEnabled = "speedAlertEnabled"
        static let speedAlertKmh = "speedAlertKmh"
    }

    private(set) var units: UnitSystem
    private(set) var speedAlertEnabled: Bool
    /// Seuil d'alerte, toujours conservé en km/h.
    private(set) var speedAlertKmh: Double

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Key.units), let stored = UnitSystem(rawValue: raw) {
            units = stored
        } else {
            // Premier lancement : miles là où la région de l'appareil les utilise.
            units = Locale.current.measurementSystem == .metric ? .metric : .imperial
        }
        speedAlertEnabled = defaults.bool(forKey: Key.speedAlertEnabled)
        let storedThreshold: Double = defaults.double(forKey: Key.speedAlertKmh)
        speedAlertKmh = storedThreshold > 0 ? storedThreshold : 90
    }

    func setUnits(_ value: UnitSystem) {
        units = value
        defaults.set(value.rawValue, forKey: Key.units)
    }

    func setSpeedAlertEnabled(_ value: Bool) {
        speedAlertEnabled = value
        defaults.set(value, forKey: Key.speedAlertEnabled)
    }

    func setSpeedAlertKmh(_ value: Double) {
        let clamped: Double = min(Self.speedAlertRange.upperBound, max(Self.speedAlertRange.lowerBound, value))
        speedAlertKmh = clamped
        defaults.set(clamped, forKey: Key.speedAlertKmh)
    }

    /// Seuil dans l'unité affichée, arrondi au pas de réglage.
    var speedAlertDisplayValue: Double {
        let value: Double = units.speed(fromKmh: speedAlertKmh)
        return (value / Self.speedAlertStep).rounded() * Self.speedAlertStep
    }

    /// Bornes du seuil dans l'unité affichée.
    var speedAlertDisplayRange: ClosedRange<Double> {
        let low: Double = (units.speed(fromKmh: Self.speedAlertRange.lowerBound) / Self.speedAlertStep).rounded(.up)
        let high: Double = (units.speed(fromKmh: Self.speedAlertRange.upperBound) / Self.speedAlertStep).rounded(.down)
        return (low * Self.speedAlertStep)...(high * Self.speedAlertStep)
    }

    func setSpeedAlertDisplayValue(_ value: Double) {
        setSpeedAlertKmh(units.kmh(fromSpeed: value))
    }
}
