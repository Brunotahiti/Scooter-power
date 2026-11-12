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

    public init(distanceMeters: Double, maxSpeedKmh: Double, averageSpeedKmh: Double,
                peakAcceleration: Double, maxLeanLeftDegrees: Double, maxLeanRightDegrees: Double,
                movingDuration: TimeInterval, totalDuration: TimeInterval) {
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

    private var needsCalibration = true

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
    }

    public mutating func handle(_ sample: MotionSample) {
        guard state == .recording || state == .paused else { return }
        if needsCalibration, lean.calibrate(gravity: sample.gravity) {
            needsCalibration = false
        }
        guard let calibration = lean.calibration else { return }
        lean.update(gravity: sample.gravity, timestamp: sample.timestamp)
        acceleration.addSensor(
            timestamp: sample.timestamp,
            longitudinal: calibration.longitudinalAcceleration(userAccelerationG: sample.userAcceleration))
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
            totalDuration: statistics.totalDuration(at: now))
    }
}
