import Foundation
import Observation
import ScooterCore
import UIKit

/// Enveloppe observable de `TripSession` : relie les capteurs à la session
/// et publie des valeurs prêtes à afficher.
@MainActor
@Observable
final class TripViewModel {
    private(set) var state = TripState.idle
    private(set) var isDemo: Bool
    private(set) var locationDenied = false
    private(set) var gpsWeak = false

    private(set) var speedKmh: Double?
    /// Vitesse dans l'unité affichée, pour le compteur.
    private(set) var speedValue: Double?
    private(set) var speedUnit = "km/h"
    private(set) var speedometerMax: Double = 140
    private(set) var speedometerStep: Double = 20
    /// Le seuil d'alerte de vitesse est dépassé.
    private(set) var speedAlertActive = false
    private(set) var speedText = "--"
    private(set) var maxSpeedText = "--"
    private(set) var averageSpeedText = "--"
    private(set) var distanceText = "--"
    private(set) var altitudeText = "--"
    private(set) var movingDurationText = "00:00:00"
    private(set) var totalDurationText = "00:00:00"

    private(set) var accelerationValue: Double = 0
    private(set) var accelerationText = "0"
    private(set) var accelerationLevel = AccelerationLevel.stable
    private(set) var accelerationHistory: [Double] = []
    private(set) var peakText = "--"

    /// Meilleurs temps du trajet, ou `--`, dans l'ordre de `SpeedInterval.all`.
    private(set) var sprintTexts: [String] = SpeedInterval.all.map { _ in "--" }
    /// Une mesure est en cours : départ arrêté ou reprise lancée.
    private(set) var sprintRunning = false
    private(set) var sprintElapsedText = ""
    /// Records tous trajets confondus, ou `--`, dans l'ordre de `SpeedInterval.all`.
    private(set) var recordTexts: [String] = SpeedInterval.all.map { _ in "--" }
    /// Indices, dans `SpeedInterval.all`, des records battus pendant ce trajet.
    private(set) var beatenRecords: Set<Int> = []
    /// Annonce « Record battu » à afficher quelques secondes, ou `nil`.
    private(set) var recordBanner: RecordBanner?

    private(set) var leanDegrees: Double = 0
    private(set) var leanText = "0°"
    private(set) var leanSide = LeanSide.upright

    private(set) var route: [Coordinate] = []
    private(set) var summary: TripSummary?
    /// Début du trajet en cours ou du dernier trajet terminé.
    private(set) var startDate: Date?

    @ObservationIgnored private var session = TripSession()
    @ObservationIgnored private let location: LocationProviding
    @ObservationIgnored private let motion: MotionProviding
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var startRequested = false
    @ObservationIgnored private let settings = AppSettings.shared
    @ObservationIgnored private var speedAlert = SpeedAlert()
    @ObservationIgnored private var recordBook = RecordBook()
    /// Nombre de mesures de `session.sprint.results` déjà comparées aux records.
    @ObservationIgnored private var checkedResults = 0
    @ObservationIgnored private var bannerHideTime: TimeInterval = 0
    @ObservationIgnored private var bannerCount = 0
    @ObservationIgnored private let liveActivity = LiveActivityController()

    /// Capteurs réels s'ils existent, sinon trajet de démonstration (simulateur).
    convenience init() {
        let motion = MotionService()
        if motion.isAvailable {
            self.init(location: LocationService(), motion: motion, isDemo: false)
        } else {
            let demo = DemoFeed()
            self.init(location: demo, motion: demo, isDemo: true)
        }
    }

    init(location: LocationProviding, motion: MotionProviding, isDemo: Bool) {
        self.location = location
        self.motion = motion
        self.isDemo = isDemo

        // Les échantillons modifient la session à leur cadence ; l'écran n'est
        // rafraîchi qu'à 10 Hz par `refresh()`.
        location.onLocation = { [weak self] sample in
            self?.session.handle(sample)
        }
        motion.onMotion = { [weak self] sample in
            self?.session.handle(sample)
        }
        location.onAuthorizationChange = { [weak self] authorization in
            self?.authorizationChanged(authorization)
        }
        liveActivity.endOrphans()
        // Met les textes au bon format (unités, séparateur décimal) dès l'ouverture.
        refresh()
    }

    private var now: TimeInterval { Date().timeIntervalSinceReferenceDate }

    // MARK: - Actions

    func start() {
        guard state == .idle else { return }
        switch location.authorization {
        case .authorized:
            begin()
        case .notDetermined:
            startRequested = true
            location.requestAuthorization()
        case .denied:
            locationDenied = true
        }
    }

    func togglePause() {
        switch state {
        case .recording:
            session.pause(at: now)
        case .paused:
            session.resume(at: now)
        case .idle, .finished:
            return
        }
        refresh()
    }

    func finish() {
        guard state == .recording || state == .paused else { return }
        let time = now
        session.finish(at: time)
        location.stop()
        motion.stop()
        stopRefreshing()
        // Le rafraîchissement s'arrête : l'annonce ne se refermerait plus toute seule.
        recordBanner = nil
        liveActivity.end()
        UIApplication.shared.isIdleTimerDisabled = false
        // Le résumé est prêt avant que `state` ne passe à `.finished` : la vue l'enregistre à ce moment-là.
        summary = session.summary(at: time)
        refresh()
    }

    func reset() {
        guard state == .finished else { return }
        session.reset()
        summary = nil
        refresh()
    }

    /// Records issus de l'historique des trajets. À rappeler quand l'historique change.
    func setHistoryRecords(_ records: [SpeedInterval: TimeInterval]) {
        var book = RecordBook(records: records)
        // Le trajet en cours n'est pas encore dans l'historique.
        book.merge(session.sprint.bestTimes)
        recordBook = book
        publishRecords()
    }

    /// À appeler quand un réglage d'affichage change : les textes sont recalculés.
    func settingsChanged() {
        refresh()
    }

    func recalibrate() {
        session.recalibrate()
    }

    // MARK: - Interne

    private func authorizationChanged(_ authorization: LocationAuthorization) {
        locationDenied = authorization == .denied
        guard startRequested, authorization != .notDetermined else { return }
        startRequested = false
        if authorization == .authorized {
            begin()
        }
    }

    private func begin() {
        guard state == .idle else { return }
        startDate = Date()
        checkedResults = 0
        beatenRecords = []
        recordBanner = nil
        session.start(at: now)
        location.start()
        motion.start()
        UIApplication.shared.isIdleTimerDisabled = true
        startRefreshing()
        refresh()
        liveActivity.start(startDate: startDate ?? Date(), state: liveActivityState)
    }

    private var liveActivityState: LiveActivityController.State {
        LiveActivityController.State(
            speedText: speedText,
            speedUnit: speedUnit,
            distanceText: distanceText,
            durationText: totalDurationText,
            isPaused: state == .paused,
            // Arrondis à la précision affichée, pour ne pas envoyer de mise à jour sans effet visible.
            acceleration: (accelerationValue * 10).rounded() / 10,
            leanDegrees: leanDegrees.rounded())
    }

    /// Compare les nouvelles mesures aux records et annonce ceux qui tombent.
    private func checkRecords(_ results: [SprintResult], at time: TimeInterval) {
        if recordBanner != nil, time >= bannerHideTime {
            recordBanner = nil
        }
        guard results.count > checkedResults else { return }
        for result in results[checkedResults...] {
            let outcome = recordBook.submit(result.interval, time: result.time)
            guard case .beaten(let previous) = outcome else { continue }
            if let index = SpeedInterval.all.firstIndex(of: result.interval) {
                beatenRecords.insert(index)
            }
            bannerCount += 1
            recordBanner = RecordBanner(
                id: bannerCount,
                title: result.interval.label + " km/h",
                time: Self.sprintText(result.time),
                previous: Self.sprintText(previous))
            bannerHideTime = time + RecordBanner.duration
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        checkedResults = results.count
        publishRecords()
    }

    private func publishRecords() {
        recordTexts = SpeedInterval.all.map { Self.sprintText(recordBook.records[$0]) }
    }

    private static func sprintText(_ time: TimeInterval?) -> String {
        guard let time else { return "--" }
        return Formatters.decimal(time, digits: 1) + " s"
    }

    private func startRefreshing() {
        stopRefreshing()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refresh() {
        let time = now
        let statistics = session.statistics
        let acceleration = session.acceleration
        let lean = session.lean

        state = session.state

        let units: UnitSystem = settings.units
        speedUnit = units.speedUnit
        speedometerMax = units.speedometerMax
        speedometerStep = units.speedometerLabelStep

        speedKmh = statistics.currentSpeedKmh(at: time)
        speedValue = speedKmh.map { units.speed(fromKmh: $0) }
        speedText = speedValue.map { Formatters.decimal($0, digits: 0) } ?? "--"

        let alertFired: Bool = speedAlert.update(
            speedKmh: speedKmh,
            thresholdKmh: settings.speedAlertKmh,
            enabled: settings.speedAlertEnabled && state == .recording)
        speedAlertActive = speedAlert.isOver
        if alertFired {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        gpsWeak = state == .recording && speedKmh == nil

        let hasTrip = state != .idle
        maxSpeedText = hasTrip ? Formatters.decimal(units.speed(fromKmh: statistics.maxSpeedKmh), digits: 0) : "--"
        averageSpeedText = hasTrip
            ? Formatters.decimal(units.speed(fromKmh: statistics.averageSpeedKmh), digits: 0) : "--"
        distanceText = Formatters.decimal(units.distance(fromMeters: statistics.distanceMeters), digits: 1)
            + " " + units.distanceUnit
        let altitude: String = statistics.altitudeMeters
            .map { Formatters.decimal(units.altitude(fromMeters: $0), digits: 0) } ?? "--"
        altitudeText = altitude + " " + units.altitudeUnit
        movingDurationText = Formatters.duration(statistics.movingDuration)
        totalDurationText = Formatters.duration(statistics.totalDuration(at: time))

        accelerationValue = acceleration.current
        accelerationText = Formatters.signed(acceleration.current, digits: 1)
        accelerationLevel = acceleration.level
        accelerationHistory = acceleration.history
        peakText = Formatters.signed(acceleration.peak, digits: 1) + " m/s²"

        let sprint = session.sprint
        checkRecords(sprint.results, at: time)
        sprintTexts = SpeedInterval.all.map { Self.sprintText(sprint.best($0)) }
        sprintRunning = sprint.isRunning || sprint.isRolling
        sprintElapsedText = sprint.activeElapsed(at: time).map { Formatters.decimal($0, digits: 1) } ?? ""

        leanDegrees = lean.angleDegrees
        leanSide = lean.side
        leanText = Formatters.decimal(abs(lean.angleDegrees), digits: 0) + "°"

        if route.count != statistics.route.count {
            route = statistics.route
        }

        if state == .recording || state == .paused {
            liveActivity.update(liveActivityState)
        }
    }
}

/// Annonce d'un record battu.
struct RecordBanner: Identifiable, Equatable {
    /// Durée d'affichage, en secondes.
    static let duration: TimeInterval = 5

    let id: Int
    /// Plage concernée, par exemple « 0–50 km/h ».
    let title: String
    /// Nouveau record, par exemple « 4,2 s ».
    let time: String
    /// Ancien record.
    let previous: String
}
