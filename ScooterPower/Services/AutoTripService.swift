import CoreLocation
import CoreMotion
import Observation
import ScooterCore
import UIKit
import UserNotifications

/// Démarrage et arrêt automatiques des trajets.
/// - App ouverte et à l'arrêt : le GPS surveille la vitesse ; au-delà de
///   15 km/h pendant 15 s, l'enregistrement démarre.
/// - Pendant un trajet : 3 min à l'arrêt complet, le trajet se termine.
/// - App fermée (option, position « Toujours ») : un grand déplacement
///   réveille l'app ; si l'iPhone dit qu'on est en véhicule, une notification
///   propose d'enregistrer (iOS n'autorise pas à démarrer seul le GPS ici).
@MainActor
@Observable
final class AutoTripService: NSObject {
    static let shared = AutoTripService()
    private static let enabledKey = "autoTripEnabled"
    private static let backgroundKey = "autoTripBackground"
    private static let notificationID = "autoTripDetected"
    static let notificationCategory = "AUTO_TRIP"

    private(set) var isEnabled: Bool = UserDefaults.standard.bool(forKey: AutoTripService.enabledKey)
    private(set) var backgroundEnabled: Bool = UserDefaults.standard.bool(forKey: AutoTripService.backgroundKey)
    /// Vrai pendant la surveillance à l'arrêt (app ouverte).
    private(set) var isWatching = false

    /// Le trajet est-il à l'arrêt (pas d'enregistrement en cours) ?
    @ObservationIgnored var isIdle: () -> Bool = { true }

    @ObservationIgnored private let probe = CLLocationManager()
    @ObservationIgnored private let significant = CLLocationManager()
    @ObservationIgnored private let activity = CMMotionActivityManager()
    @ObservationIgnored private var detector = AutoTripDetector()
    @ObservationIgnored private var stopDetector = AutoTripDetector()
    @ObservationIgnored private var lastNotification: Date?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        probe.delegate = self
        probe.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        probe.activityType = .automotiveNavigation
        significant.delegate = self
    }

    /// À appeler au lancement de l'app (aussi quand iOS la réveille en arrière-plan).
    func activate() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshWatching() }
            },
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stopWatching() }
            },
        ]
        refreshBackgroundMonitoring()
        refreshWatching()
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
        if !value { setBackgroundEnabled(false) }
        refreshWatching()
    }

    func setBackgroundEnabled(_ value: Bool) {
        backgroundEnabled = value
        UserDefaults.standard.set(value, forKey: Self.backgroundKey)
        if value {
            significant.requestAlwaysAuthorization()
            LocalNotifier.requestPermission()
        }
        refreshBackgroundMonitoring()
    }

    /// Le trajet vient de commencer ou de finir : surveillance à l'arrêt ou non.
    func tripStateChanged() {
        stopDetector.reset()
        refreshWatching()
    }

    // MARK: - App ouverte : départ automatique

    private func refreshWatching() {
        let active: Bool = UIApplication.shared.applicationState == .active
        if isEnabled, active, isIdle() {
            guard !isWatching else { return }
            detector.reset()
            probe.startUpdatingLocation()
            isWatching = true
        } else {
            stopWatching()
        }
    }

    private func stopWatching() {
        guard isWatching else { return }
        probe.stopUpdatingLocation()
        isWatching = false
    }

    private func probeSample(_ location: CLLocation) {
        guard isWatching, location.speed >= 0, location.horizontalAccuracy >= 0, location.horizontalAccuracy < 50 else { return }
        let started: Bool = detector.idleSample(time: location.timestamp.timeIntervalSinceReferenceDate, kmh: location.speed * 3.6)
        guard started, isIdle() else { return }
        stopWatching()
        TripCommands.shared.request(.start)
        if AppSettings.shared.voiceEnabled {
            Announcer.shared.say(L("Départ détecté, l'enregistrement commence."))
        }
    }

    // MARK: - Pendant le trajet : arrêt automatique

    /// Vitesse pendant l'enregistrement ; vrai quand il faut terminer le trajet.
    func ridingSample(time: TimeInterval, kmh: Double) -> Bool {
        guard isEnabled else { return false }
        return stopDetector.ridingSample(time: time, kmh: kmh)
    }

    // MARK: - App fermée : notification

    private func refreshBackgroundMonitoring() {
        let always: Bool = significant.authorizationStatus == .authorizedAlways
        if isEnabled, backgroundEnabled, always, CLLocationManager.significantLocationChangeMonitoringAvailable() {
            significant.startMonitoringSignificantLocationChanges()
        } else {
            significant.stopMonitoringSignificantLocationChanges()
        }
    }

    private func significantChange() {
        guard isEnabled, backgroundEnabled, isIdle(), UIApplication.shared.applicationState != .active else { return }
        if let lastNotification, Date().timeIntervalSince(lastNotification) < 20 * 60 { return }
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activity.queryActivityStarting(from: Date().addingTimeInterval(-180), to: Date(), to: .main) { [weak self] activities, _ in
            let driving: Bool = (activities ?? []).contains { ($0.automotive || $0.cycling) && $0.confidence != .low }
            guard driving else { return }
            MainActor.assumeIsolated { self?.notifyRiding() }
        }
    }

    private func notifyRiding() {
        lastNotification = Date()
        let content = UNMutableNotificationContent()
        content.title = L("Tu roules ? 🛵")
        content.body = L("Touche pour enregistrer ce trajet dans Scooter Power.")
        content.sound = .default
        content.categoryIdentifier = Self.notificationCategory
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: nil))
    }
}

extension AutoTripService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        MainActor.assumeIsolated {
            if manager === self.probe {
                self.probeSample(last)
            } else {
                self.significantChange()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            if manager === self.significant { self.refreshBackgroundMonitoring() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
