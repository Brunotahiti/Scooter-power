import Foundation

/// Chronomètre les accélérations départ arrêté : 0–50 et 0–80 km/h.
///
/// Le GPS ne fournit qu'un point par seconde ; les instants de départ et de
/// passage sont interpolés linéairement entre deux points.
public struct SprintTimer: Sendable {
    /// Sous cette vitesse, le scooter est considéré à l'arrêt (km/h).
    public static let standstillSpeed = 1.0
    /// Tant que la vitesse reste sous ce seuil, le scooter avance au pas et le
    /// départ n'est pas encore donné (km/h).
    public static let launchSpeed = 5.0
    /// Durée au pas après laquelle le départ est reporté (s).
    public static let maxCreep = 2.0
    public static let firstTarget = 50.0
    public static let secondTarget = 80.0
    /// Baisse de vitesse, par rapport au maximum de la mesure, qui annule celle-ci (km/h).
    public static let cancelDrop = 3.0
    /// Écart maximal entre deux points pendant une mesure (s).
    public static let maxGap = 3.0
    public static let maxDuration = 60.0
    /// En dessous, le temps est attribué à un saut GPS et rejeté (s).
    public static let minPlausibleTime = 1.5

    private enum State: Sendable {
        case idle
        case armed(time: TimeInterval, speed: Double)
        case running(start: TimeInterval, maxSpeed: Double, gotFirst: Bool)
    }

    private var state = State.idle
    private var previous: (time: TimeInterval, speed: Double)?

    public private(set) var last50: TimeInterval?
    public private(set) var best50: TimeInterval?
    public private(set) var last80: TimeInterval?
    public private(set) var best80: TimeInterval?

    public init() {}

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// Temps écoulé depuis le départ de la mesure en cours.
    public func runElapsed(at now: TimeInterval) -> TimeInterval? {
        guard case .running(let start, _, _) = state else { return nil }
        return max(0, now - start)
    }

    /// Abandonne la mesure en cours ; les temps déjà obtenus sont conservés.
    public mutating func cancelRun() {
        state = .idle
    }

    public mutating func add(timestamp: TimeInterval, speedKmh: Double) {
        guard timestamp.isFinite, speedKmh.isFinite, speedKmh >= 0 else { return }
        if let previous, timestamp <= previous.time { return }
        let before = previous
        previous = (timestamp, speedKmh)

        if speedKmh < Self.standstillSpeed {
            state = .armed(time: timestamp, speed: speedKmh)
            return
        }

        switch state {
        case .idle:
            return

        case .armed(let restTime, let restSpeed):
            guard timestamp - restTime <= Self.maxGap else {
                state = .idle
                return
            }
            // Toujours au pas : le point de départ suit le scooter.
            if restSpeed >= Self.standstillSpeed, speedKmh < Self.launchSpeed {
                state = .armed(time: timestamp, speed: speedKmh)
                return
            }
            let start = Self.crossing(of: Self.standstillSpeed,
                                      from: (restTime, restSpeed), to: (timestamp, speedKmh))
            state = .running(start: start, maxSpeed: speedKmh, gotFirst: false)
            checkTargets(from: (restTime, restSpeed), to: (timestamp, speedKmh))

        case .running(let start, let maxSpeed, let gotFirst):
            // Parti de l'arrêt mais resté au pas : ce n'est pas un départ, on réarme ici.
            if maxSpeed < Self.launchSpeed, speedKmh < Self.launchSpeed, timestamp - start > Self.maxCreep {
                state = .armed(time: timestamp, speed: speedKmh)
                return
            }
            guard let before,
                  timestamp - before.time <= Self.maxGap,
                  timestamp - start <= Self.maxDuration,
                  speedKmh >= maxSpeed - Self.cancelDrop
            else {
                state = .idle
                return
            }
            state = .running(start: start, maxSpeed: max(maxSpeed, speedKmh), gotFirst: gotFirst)
            checkTargets(from: before, to: (timestamp, speedKmh))
        }
    }

    /// Enregistre les seuils franchis entre deux points consécutifs.
    private mutating func checkTargets(from a: (time: TimeInterval, speed: Double),
                                       to b: (time: TimeInterval, speed: Double)) {
        guard case .running(let start, let maxSpeed, var gotFirst) = state else { return }

        if !gotFirst, a.speed < Self.firstTarget, b.speed >= Self.firstTarget {
            let time = Self.crossing(of: Self.firstTarget, from: a, to: b) - start
            guard time >= Self.minPlausibleTime else {
                state = .idle
                return
            }
            last50 = time
            best50 = min(best50 ?? time, time)
            gotFirst = true
            state = .running(start: start, maxSpeed: maxSpeed, gotFirst: true)
        }

        if a.speed < Self.secondTarget, b.speed >= Self.secondTarget {
            let time = Self.crossing(of: Self.secondTarget, from: a, to: b) - start
            if gotFirst, time >= Self.minPlausibleTime {
                last80 = time
                best80 = min(best80 ?? time, time)
            }
            state = .idle
        }
    }

    /// Instant où la vitesse atteint `target`, par interpolation linéaire.
    private static func crossing(of target: Double,
                                 from a: (time: TimeInterval, speed: Double),
                                 to b: (time: TimeInterval, speed: Double)) -> TimeInterval {
        let span = b.speed - a.speed
        guard span > 0 else { return b.time }
        let ratio = min(1, max(0, (target - a.speed) / span))
        return a.time + ratio * (b.time - a.time)
    }
}
