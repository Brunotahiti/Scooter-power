import Foundation

/// Opérations d'entretien courantes, avec leurs intervalles habituels pour un
/// maxi-scooter (à ajuster selon le carnet du constructeur).
public enum MaintenanceKind: String, Sendable, Codable, CaseIterable {
    case oil, service, rearTyre, frontTyre, belt, brakePads, custom

    /// Intervalle conseillé par défaut : kilomètres et/ou mois.
    public var defaultInterval: (km: Double?, months: Int?) {
        switch self {
        case .oil: return (5_000, 12)
        case .service: return (10_000, 12)
        case .rearTyre: return (8_000, nil)
        case .frontTyre: return (12_000, nil)
        case .belt: return (20_000, 24)
        case .brakePads: return (10_000, nil)
        case .custom: return (nil, 12)
        }
    }
}

/// État d'une opération d'entretien.
public enum MaintenanceState: Sendable, Equatable {
    case ok
    /// Échéance proche : moins de 10 % de l'intervalle (et au plus 500 km) ou moins de 30 jours.
    case soon
    case due
}

/// Échéance d'une opération, calculée à partir du dernier entretien.
public struct MaintenanceStatus: Sendable, Equatable {
    /// Kilomètres restants (négatif si dépassé), ou `nil` sans intervalle en km.
    public var remainingKm: Double?
    /// Jours restants (négatif si dépassé), ou `nil` sans intervalle en mois.
    public var remainingDays: Int?
    /// Part de l'intervalle déjà consommée, de 0 à 1 (la plus avancée des deux).
    public var progress: Double
    public var state: MaintenanceState

    public static let soonDays = 30
    public static let soonKmMax: Double = 500

    public static func compute(intervalKm: Double?, intervalMonths: Int?, lastDoneKm: Double, lastDoneDate: Date,
                               currentKm: Double, now: Date, calendar: Calendar = .current) -> MaintenanceStatus {
        var remainingKm: Double?
        var remainingDays: Int?
        var progress: Double = 0
        var state = MaintenanceState.ok

        if let intervalKm, intervalKm > 0 {
            let used: Double = max(0, currentKm - lastDoneKm)
            let remaining: Double = intervalKm - used
            remainingKm = remaining
            progress = max(progress, min(1, used / intervalKm))
            if remaining <= 0 {
                state = .due
            } else if remaining <= min(soonKmMax, intervalKm * 0.1) {
                state = .soon
            }
        }
        if let intervalMonths, intervalMonths > 0,
           let dueDate = calendar.date(byAdding: .month, value: intervalMonths, to: lastDoneDate) {
            let total: Double = dueDate.timeIntervalSince(lastDoneDate)
            let used: Double = now.timeIntervalSince(lastDoneDate)
            progress = max(progress, min(1, max(0, used / total)))
            let days: Int = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)).day ?? 0
            remainingDays = days
            if days <= 0 {
                state = .due
            } else if days <= soonDays, state == .ok {
                state = .soon
            }
        }
        return MaintenanceStatus(remainingKm: remainingKm, remainingDays: remainingDays, progress: progress, state: state)
    }
}

/// Un plein de carburant.
public struct FuelFill: Sendable, Equatable {
    public var odometerKm: Double
    public var liters: Double

    public init(odometerKm: Double, liters: Double) {
        self.odometerKm = odometerKm
        self.liters = liters
    }
}

/// Consommation moyenne, méthode « plein à plein » : les litres remis depuis le
/// premier plein, divisés par la distance parcourue depuis.
public enum FuelEconomy {
    /// Litres aux 100 km, ou `nil` s'il faut au moins deux pleins.
    public static func litersPer100Km(_ fills: [FuelFill]) -> Double? {
        let sorted: [FuelFill] = fills
            .filter { $0.odometerKm.isFinite && $0.liters.isFinite && $0.liters > 0 }
            .sorted { $0.odometerKm < $1.odometerKm }
        guard sorted.count >= 2, let first = sorted.first, let last = sorted.last else { return nil }
        let distance: Double = last.odometerKm - first.odometerKm
        guard distance > 0 else { return nil }
        let liters: Double = sorted.dropFirst().reduce(0) { $0 + $1.liters }
        return liters / distance * 100
    }

    /// Miles par gallon US, à partir de litres aux 100 km.
    public static func mpg(fromLitersPer100Km value: Double) -> Double {
        guard value > 0 else { return 0 }
        return 235.214583 / value
    }
}
