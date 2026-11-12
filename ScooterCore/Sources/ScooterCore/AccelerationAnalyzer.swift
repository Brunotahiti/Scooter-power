import Foundation

public enum AccelerationLevel: Sendable {
    case brakingHard, braking, stable, accelerating, acceleratingHard
}

/// Accélération longitudinale lissée.
///
/// L'accéléromètre donne la réactivité ; la dérivée de la vitesse GPS corrige
/// sa dérive (biais de montage, pente). Les horloges des deux sources ne sont
/// jamais comparées entre elles.
public struct AccelerationAnalyzer: Sendable {
    public static let historyCapacity = 120
    public static let historyInterval = 0.25
    public static let smoothingTimeConstant = 0.3
    public static let biasTimeConstant = 2.0
    /// Pleine échelle de la jauge, en m/s².
    public static let gaugeFullScale = 4.0
    /// Au-delà de cet écart entre deux échantillons, le filtre repart de la nouvelle valeur.
    public static let maxSensorGap = 1.0
    /// Au-delà de cet écart entre deux points GPS, la dérivée n'est pas utilisée.
    public static let maxGPSGap = 5.0

    /// m/s², signée : positive en accélération, négative au freinage.
    public private(set) var current: Double = 0
    /// Une valeur par 0,25 s sur 30 s, la plus récente en dernier.
    public private(set) var history: [Double] = []
    /// Maximum positif de `current` depuis la création.
    public private(set) var tripPeak: Double = 0

    private var bias: Double = 0
    private var lastSensorTime: TimeInterval?
    private var nextHistoryTime: TimeInterval = 0
    private var sensorSum: Double = 0
    private var sensorCount: Int = 0
    private var lastGPS: (time: TimeInterval, speed: Double)?

    public init() {}

    public var level: AccelerationLevel { Self.level(for: current) }

    public static func level(for value: Double) -> AccelerationLevel {
        if value <= -2.5 { return .brakingHard }
        if value <= -0.8 { return .braking }
        if value >= 2.5 { return .acceleratingHard }
        if value >= 0.8 { return .accelerating }
        return .stable
    }

    /// Maximum positif des 30 dernières secondes.
    public var peak: Double { max(0, history.max() ?? 0) }

    /// `current` ramené dans [−1, 1] pour la jauge.
    public var gaugePosition: Double {
        min(1, max(-1, current / Self.gaugeFullScale))
    }

    /// Accélération longitudinale mesurée par le capteur, en m/s².
    /// `trackPeak` à `false` met à jour l'affichage sans compter dans `tripPeak` (trajet en pause).
    public mutating func addSensor(timestamp: TimeInterval, longitudinal: Double, trackPeak: Bool = true) {
        guard timestamp.isFinite, longitudinal.isFinite else { return }
        sensorSum += longitudinal
        sensorCount += 1
        let fused = longitudinal - bias

        if let last = lastSensorTime, timestamp - last > 0, timestamp - last <= Self.maxSensorGap {
            let dt = timestamp - last
            current += (fused - current) * dt / (Self.smoothingTimeConstant + dt)
        } else {
            // Premier échantillon ou reprise après un trou : on repart de zéro et le
            // filtre converge, pour qu'une mesure isolée ne devienne jamais un pic.
            current = 0
            nextHistoryTime = timestamp
        }
        lastSensorTime = timestamp
        if trackPeak {
            tripPeak = max(tripPeak, current)
        }

        if timestamp >= nextHistoryTime {
            history.append(current)
            if history.count > Self.historyCapacity {
                history.removeFirst(history.count - Self.historyCapacity)
            }
            nextHistoryTime += Self.historyInterval
            if nextHistoryTime <= timestamp {
                nextHistoryTime = timestamp + Self.historyInterval
            }
        }
    }

    /// Vitesse GPS en m/s. Sert uniquement à corriger la dérive du capteur.
    public mutating func addGPSSpeed(timestamp: TimeInterval, speed: Double) {
        guard timestamp.isFinite, speed.isFinite, speed >= 0 else { return }
        if let previous = lastGPS, sensorCount > 0 {
            let dt = timestamp - previous.time
            if dt > 0, dt <= Self.maxGPSGap {
                let gpsAcceleration = (speed - previous.speed) / dt
                let error = (sensorSum / Double(sensorCount) - bias) - gpsAcceleration
                bias += error * dt / (Self.biasTimeConstant + dt)
            }
        }
        lastGPS = (timestamp, speed)
        sensorSum = 0
        sensorCount = 0
    }
}
