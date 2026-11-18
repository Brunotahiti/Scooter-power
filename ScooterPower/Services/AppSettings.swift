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
        static let currentSetup = "currentSetup"
        static let riderName = "riderName"
        static let crashDetection = "crashDetectionEnabled"
        static let voice = "voiceEnabled"
        static let currentScooter = "currentScooterID"
        static let emergencyContacts = "emergencyContacts"
    }

    private(set) var units: UnitSystem
    /// Langue de l'app ; anglais par défaut.
    private(set) var language: AppLanguage = AppLanguage.stored
    private(set) var speedAlertEnabled: Bool
    /// Seuil d'alerte, toujours conservé en km/h.
    private(set) var speedAlertKmh: Double
    /// Nom de la configuration actuelle du scooter (« Origine », « Variateur sport »…).
    /// Chaque trajet est enregistré avec ce nom, pour comparer avant et après une modification.
    private(set) var currentSetup: String
    /// Pseudo affiché sur la carte de performances partagée.
    private(set) var riderName: String
    /// Scooter du garage utilisé pour les prochains trajets (`Scooter.uid`).
    private(set) var currentScooterID: String? = UserDefaults.standard.string(forKey: Key.currentScooter)
    /// Annonces vocales (records, chronos, alerte de vitesse) ; activées par défaut.
    private(set) var voiceEnabled: Bool = UserDefaults.standard.object(forKey: Key.voice) as? Bool ?? true
    /// Surveillance des chutes pendant les trajets ; activée par défaut.
    private(set) var crashDetectionEnabled: Bool = UserDefaults.standard.object(forKey: Key.crashDetection) as? Bool ?? true
    /// Personnes prévenues en cas de chute (3 au plus).
    private(set) var emergencyContacts: [EmergencyContact] = AppSettings.loadContacts()

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Tout est d'abord calculé dans des variables locales : une propriété
        // observable ne peut pas être relue tant que l'objet n'est pas entièrement initialisé.
        let chosenUnits: UnitSystem
        if let raw = defaults.string(forKey: Key.units), let stored = UnitSystem(rawValue: raw) {
            chosenUnits = stored
        } else {
            // Premier lancement : miles là où la région de l'appareil les utilise.
            chosenUnits = Locale.current.measurementSystem == .metric ? .metric : .imperial
        }

        // Par défaut, un seuil rond dans l'unité affichée : 90 km/h ou 55 mph.
        let defaultThreshold: Double = chosenUnits == .metric ? 90 : chosenUnits.kmh(fromSpeed: 55)
        let storedThreshold: Double = defaults.double(forKey: Key.speedAlertKmh)

        units = chosenUnits
        speedAlertEnabled = defaults.bool(forKey: Key.speedAlertEnabled)
        speedAlertKmh = storedThreshold > 0 ? storedThreshold : defaultThreshold
        currentSetup = Self.cleaned(defaults.string(forKey: Key.currentSetup) ?? "")
        riderName = defaults.string(forKey: Key.riderName) ?? ""
    }

    func setCurrentScooter(_ id: String?) {
        currentScooterID = id
        defaults.set(id, forKey: Key.currentScooter)
    }

    func setVoiceEnabled(_ value: Bool) {
        voiceEnabled = value
        defaults.set(value, forKey: Key.voice)
    }

    func setCrashDetectionEnabled(_ value: Bool) {
        crashDetectionEnabled = value
        defaults.set(value, forKey: Key.crashDetection)
    }

    static let maxEmergencyContacts = 3

    func addEmergencyContact(_ contact: EmergencyContact) {
        guard emergencyContacts.count < Self.maxEmergencyContacts,
              !emergencyContacts.contains(where: { $0.phone == contact.phone })
        else { return }
        emergencyContacts.append(contact)
        saveContacts()
    }

    func removeEmergencyContacts(at offsets: IndexSet) {
        emergencyContacts.remove(atOffsets: offsets)
        saveContacts()
    }

    private func saveContacts() {
        defaults.set(try? JSONEncoder().encode(emergencyContacts), forKey: Key.emergencyContacts)
    }

    private static func loadContacts() -> [EmergencyContact] {
        guard let data = UserDefaults.standard.data(forKey: Key.emergencyContacts) else { return [] }
        return (try? JSONDecoder().decode([EmergencyContact].self, from: data)) ?? []
    }

    func setLanguage(_ value: AppLanguage) {
        AppLanguage.apply(value)
        language = value
    }

    func setRiderName(_ name: String) {
        let value: String = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(PerformanceCard.maxNameLength))
        riderName = value
        defaults.set(value, forKey: Key.riderName)
    }

    /// Nom donné aux trajets enregistrés sans configuration.
    static var defaultSetup: String { L("Origine") }

    /// Nom sans espaces superflus, limité à 40 caractères ; le nom par défaut s'il est vide.
    static func cleaned(_ name: String) -> String {
        let trimmed: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // « Origine » était le nom par défaut quand l'app était en français.
        if trimmed.isEmpty || trimmed == "Origine" { return defaultSetup }
        return String(trimmed.prefix(40))
    }

    func setCurrentSetup(_ name: String) {
        let value: String = Self.cleaned(name)
        currentSetup = value
        defaults.set(value, forKey: Key.currentSetup)
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

/// Personne à prévenir en cas de chute.
struct EmergencyContact: Codable, Equatable, Identifiable {
    var name: String
    var phone: String

    var id: String { phone }
}
