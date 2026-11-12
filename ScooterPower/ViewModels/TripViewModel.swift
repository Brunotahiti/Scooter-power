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
    private(set) var speedText = "--"
    private(set) var maxSpeedText = "--"
    private(set) var averageSpeedText = "--"
    private(set) var distanceText = "0,0 km"
    private(set) var altitudeText = "-- m"
    private(set) var movingDurationText = "00:00:00"
    private(set) var totalDurationText = "00:00:00"

    private(set) var accelerationValue: Double = 0
    private(set) var accelerationText = "0,0"
    private(set) var accelerationLevel = AccelerationLevel.stable
    private(set) var accelerationHistory: [Double] = []
    private(set) var peakText = "0,0 m/s²"

    /// Meilleurs temps du trajet, ou `--`.
    private(set) var sprint50Text = "--"
    private(set) var sprint80Text = "--"
    private(set) var sprintRunning = false
    private(set) var sprintElapsedText = ""

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
            distanceText: distanceText,
            durationText: totalDurationText,
            isPaused: state == .paused)
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

        speedKmh = statistics.currentSpeedKmh(at: time)
        speedText = speedKmh.map { Formatters.decimal($0, digits: 0) } ?? "--"
        gpsWeak = state == .recording && speedKmh == nil

        let hasTrip = state != .idle
        maxSpeedText = hasTrip ? Formatters.decimal(statistics.maxSpeedKmh, digits: 0) : "--"
        averageSpeedText = hasTrip ? Formatters.decimal(statistics.averageSpeedKmh, digits: 0) : "--"
        distanceText = Formatters.decimal(statistics.distanceMeters / 1000, digits: 1) + " km"
        altitudeText = (statistics.altitudeMeters.map { Formatters.decimal($0, digits: 0) } ?? "--") + " m"
        movingDurationText = Formatters.duration(statistics.movingDuration)
        totalDurationText = Formatters.duration(statistics.totalDuration(at: time))

        accelerationValue = acceleration.current
        accelerationText = Formatters.signed(acceleration.current, digits: 1)
        accelerationLevel = acceleration.level
        accelerationHistory = acceleration.history
        peakText = Formatters.signed(acceleration.peak, digits: 1) + " m/s²"

        let sprint = session.sprint
        sprint50Text = Self.sprintText(sprint.best50)
        sprint80Text = Self.sprintText(sprint.best80)
        sprintRunning = sprint.isRunning
        sprintElapsedText = sprint.runElapsed(at: time).map { Formatters.decimal($0, digits: 1) + " s" } ?? ""

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
