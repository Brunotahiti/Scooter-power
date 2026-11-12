import Foundation

public enum TripState: Sendable {
    case idle, recording, paused, finished
}

public struct TripSummary: Sendable, Equatable {
    public var distanceMeters: Double
    public var maxSpeedKmh: Double
    public var averageSpeedKmh: Double
    public var peakAcceleration: Double
    public var maxLeanLeftDegrees: Double
    public var maxLeanRightDegrees: Double
    public var movingDuration: TimeInterval
    public var totalDuration: TimeInterval
    /// Meilleur 0–50 km/h du trajet, en secondes.
    public var best50: TimeInterval?
    /// Meilleur 0–80 km/h du trajet, en secondes.
    public var best80: TimeInterval?

    public init(distanceMeters: Double, maxSpeedKmh: Double, averageSpeedKmh: Double,
                peakAcceleration: Double, maxLeanLeftDegrees: Double, maxLeanRightDegrees: Double,
                movingDuration: TimeInterval, totalDuration: TimeInterval,
                best50: TimeInterval? = nil, best80: TimeInterval? = nil) {
        self.best50 = best50
        self.best80 = best80
        self.distanceMeters = distanceMeters
        self.maxSpeedKmh = maxSpeedKmh
        self.averageSpeedKmh = averageSpeedKmh
        self.peakAcceleration = peakAcceleration
        self.maxLeanLeftDegrees = maxLeanLeftDegrees
        self.maxLeanRightDegrees = maxLeanRightDegrees
        self.movingDuration = movingDuration
        self.totalDuration = totalDuration
    }
}

/// Un trajet : sa machine à états et les trois calculs qu'elle alimente.
/// Toute transition hors séquence est sans effet.
public struct TripSession: Sendable {
    public private(set) var state = TripState.idle
    public private(set) var statistics = TripStatistics()
    public private(set) var acceleration = AccelerationAnalyzer()
    public private(set) var lean = LeanAngleEstimator()
    public private(set) var sprint = SprintTimer()

    /// Au-delà (s), la dernière vitesse GPS n'est plus utilisée pour l'inclinaison.
    public static let speedValidity = 5.0
    /// En dessous (m/s), l'inclinaison s'affiche sans compter dans les maxima :
    /// béquille, manœuvre, téléphone tourné sur son support. 5 km/h.
    public static let minSpeedForLeanRecord = 5.0 / 3.6

    private var needsCalibration = true
    private var latestSpeed: Double?
    /// Instant, sur l'horloge des mesures de mouvement, où `latestSpeed` a été reçue.
    private var latestSpeedMotionTime: TimeInterval?
    private var lastMotionTime: TimeInterval?

    public init() {}

    public mutating func start(at time: TimeInterval) {
        guard state == .idle else { return }
        reset()
        state = .recording
        statistics.start(at: time)
    }

    public mutating func pause(at time: TimeInterval) {
        guard state == .recording else { return }
        state = .paused
        statistics.pause(at: time)
        sprint.cancelRun()
    }

    public mutating func resume(at time: TimeInterval) {
        guard state == .paused else { return }
        state = .recording
        statistics.resume(at: time)
    }

    public mutating func finish(at time: TimeInterval) {
        guard state == .recording || state == .paused else { return }
        state = .finished
        statistics.stop(at: time)
    }

    public mutating func reset() {
        self = TripSession()
    }

    /// La prochaine mesure de mouvement redéfinit la position verticale.
    public mutating func recalibrate() {
        needsCalibration = true
    }

    public mutating func handle(_ sample: LocationSample) {
        guard state == .recording || state == .paused else { return }
        statistics.add(sample)
        acceleration.addGPSSpeed(timestamp: sample.timestamp, speed: sample.speed)

        guard TripStatistics.isValid(sample) else { return }
        latestSpeed = sample.speed
        latestSpeedMotionTime = lastMotionTime
        if state == .recording {
            sprint.add(timestamp: sample.timestamp, speedKmh: sample.speed * 3.6)
        }
    }

    /// Dernière vitesse GPS si elle est assez récente. Les horloges GPS et
    /// mouvement ne se comparent pas : l'âge se mesure sur l'horloge mouvement.
    private mutating func recentSpeed(at motionTime: TimeInterval) -> Double? {
        guard let latestSpeed else { return nil }
        guard let received = latestSpeedMotionTime else {
            latestSpeedMotionTime = motionTime
            return latestSpeed
        }
        let age = motionTime - received
        return age >= 0 && age <= Self.speedValidity ? latestSpeed : nil
    }

    public mutating func handle(_ sample: MotionSample) {
        guard state == .recording || state == .paused else { return }
        if needsCalibration, lean.calibrate(gravity: sample.gravity) {
            needsCalibration = false
        }
        guard let calibration = lean.calibration else { return }
        // En pause, l'affichage reste vivant mais rien ne compte pour le résumé.
        let counts = state == .recording
        lastMotionTime = sample.timestamp
        let speed = recentSpeed(at: sample.timestamp)
        let rolling = (speed ?? 0) >= Self.minSpeedForLeanRecord
        lean.update(gravity: sample.gravity, timestamp: sample.timestamp,
                    rotationRate: sample.rotationRate, speed: speed,
                    trackExtremes: counts && rolling)
        acceleration.addSensor(
            timestamp: sample.timestamp,
            longitudinal: calibration.longitudinalAcceleration(userAccelerationG: sample.userAcceleration),
            trackPeak: counts)
    }

    public func summary(at now: TimeInterval) -> TripSummary {
        TripSummary(
            distanceMeters: statistics.distanceMeters,
            maxSpeedKmh: statistics.maxSpeedKmh,
            averageSpeedKmh: statistics.averageSpeedKmh,
            peakAcceleration: acceleration.tripPeak,
            maxLeanLeftDegrees: lean.maxLeftDegrees,
            maxLeanRightDegrees: lean.maxRightDegrees,
            movingDuration: statistics.movingDuration,
            totalDuration: statistics.totalDuration(at: now),
            best50: sprint.best50,
            best80: sprint.best80)
    }
}
