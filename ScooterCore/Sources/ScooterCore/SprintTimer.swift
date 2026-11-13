import Foundation

/// Une plage de vitesse chronométrée, en km/h.
public struct SpeedInterval: Hashable, Sendable, Codable {
    public let from: Int
    public let to: Int

    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }

    public static let zeroTo30 = SpeedInterval(from: 0, to: 30)
    public static let zeroTo50 = SpeedInterval(from: 0, to: 50)
    public static let zeroTo80 = SpeedInterval(from: 0, to: 80)
    public static let zeroTo100 = SpeedInterval(from: 0, to: 100)
    public static let fiftyTo90 = SpeedInterval(from: 50, to: 90)
    public static let fiftyTo100 = SpeedInterval(from: 50, to: 100)

    /// Toutes les plages mesurées, dans l'ordre d'affichage.
    public static let all: [SpeedInterval] = [
        .zeroTo30, .zeroTo50, .zeroTo80, .zeroTo100, .fiftyTo90, .fiftyTo100,
    ]

    /// Départs arrêtés, par vitesse d'arrivée croissante.
    static let standing: [SpeedInterval] = all.filter { $0.from == 0 }.sorted { $0.to < $1.to }
    /// Reprises lancées, par vitesse d'arrivée croissante. Toutes partent de 50 km/h.
    static let rolling: [SpeedInterval] = all.filter { $0.from != 0 }.sorted { $0.to < $1.to }
    static let rollingStart = 50.0

    public var label: String { "\(from)–\(to)" }

    /// En dessous, le temps supposerait plus de 1 g d'accélération moyenne
    /// (35 km/h par seconde) : c'est un saut GPS, pas une mesure.
    var minPlausibleTime: TimeInterval { Double(to - from) / 35 }
}

/// Une mesure terminée : la plage et son temps en secondes.
public struct SprintResult: Sendable, Equatable {
    public let interval: SpeedInterval
    public let time: TimeInterval
}

/// Chronomètre les accélérations : départs arrêtés (0–30, 0–50, 0–80, 0–100 km/h)
/// et reprises lancées (50–90, 50–100 km/h).
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
    /// Baisse de vitesse, par rapport au maximum de la mesure, qui annule celle-ci (km/h).
    public static let cancelDrop = 3.0
    /// Écart maximal entre deux points pendant une mesure (s).
    public static let maxGap = 3.0
    public static let maxDuration = 60.0

    private typealias Point = (time: TimeInterval, speed: Double)

    private enum Standing: Sendable {
        case idle
        case armed(time: TimeInterval, speed: Double)
        /// `next` : indice du prochain seuil à franchir dans `SpeedInterval.standing`.
        case running(start: TimeInterval, maxSpeed: Double, next: Int)
    }

    private struct Rolling: Sendable {
        var start: TimeInterval
        var maxSpeed: Double
        /// Indice du prochain seuil à franchir dans `SpeedInterval.rolling`.
        var next: Int
    }

    private var standing = Standing.idle
    private var rolling: Rolling?
    private var previous: (time: TimeInterval, speed: Double)?
    private var lastTimes: [SpeedInterval: TimeInterval] = [:]

    /// Meilleur temps obtenu pour chaque plage.
    public private(set) var bestTimes: [SpeedInterval: TimeInterval] = [:]
    /// Toutes les mesures terminées, de la plus ancienne à la plus récente.
    public private(set) var results: [SprintResult] = []

    public init() {}

    // MARK: - Résultats

    public func last(_ interval: SpeedInterval) -> TimeInterval? { lastTimes[interval] }
    public func best(_ interval: SpeedInterval) -> TimeInterval? { bestTimes[interval] }

    public var last50: TimeInterval? { last(.zeroTo50) }
    public var best50: TimeInterval? { best(.zeroTo50) }
    public var last80: TimeInterval? { last(.zeroTo80) }
    public var best80: TimeInterval? { best(.zeroTo80) }

    /// Un départ arrêté est en cours de mesure.
    public var isRunning: Bool {
        if case .running = standing { return true }
        return false
    }

    /// Une reprise lancée est en cours de mesure.
    public var isRolling: Bool { rolling != nil }

    /// Temps écoulé depuis le départ arrêté en cours.
    public func runElapsed(at now: TimeInterval) -> TimeInterval? {
        guard case .running(let start, _, _) = standing else { return nil }
        return max(0, now - start)
    }

    /// Temps écoulé de la mesure en cours : le départ arrêté s'il y en a un,
    /// sinon la reprise.
    public func activeElapsed(at now: TimeInterval) -> TimeInterval? {
        if let elapsed = runElapsed(at: now) { return elapsed }
        guard let rolling else { return nil }
        return max(0, now - rolling.start)
    }

    /// Abandonne les mesures en cours ; les temps déjà obtenus sont conservés.
    public mutating func cancelRun() {
        standing = .idle
        rolling = nil
    }

    // MARK: - Mesure

    public mutating func add(timestamp: TimeInterval, speedKmh: Double) {
        guard timestamp.isFinite, speedKmh.isFinite, speedKmh >= 0 else { return }
        if let previous, timestamp <= previous.time { return }
        let before = previous
        let now: Point = (timestamp, speedKmh)
        previous = now

        updateRolling(from: before, to: now)
        updateStanding(from: before, to: now)
    }

    private mutating func record(_ interval: SpeedInterval, _ time: TimeInterval) {
        lastTimes[interval] = time
        bestTimes[interval] = min(bestTimes[interval] ?? time, time)
        results.append(SprintResult(interval: interval, time: time))
    }

    // MARK: Départ arrêté

    private mutating func updateStanding(from before: Point?, to now: Point) {
        if now.speed < Self.standstillSpeed {
            standing = .armed(time: now.time, speed: now.speed)
            return
        }

        switch standing {
        case .idle:
            return

        case .armed(let restTime, let restSpeed):
            guard now.time - restTime <= Self.maxGap else {
                standing = .idle
                return
            }
            // Toujours au pas : le point de départ suit le scooter.
            if restSpeed >= Self.standstillSpeed, now.speed < Self.launchSpeed {
                standing = .armed(time: now.time, speed: now.speed)
                return
            }
            let rest: Point = (restTime, restSpeed)
            let start = Self.crossing(of: Self.standstillSpeed, from: rest, to: now)
            standing = .running(start: start, maxSpeed: now.speed, next: 0)
            checkStandingTargets(from: rest, to: now)

        case .running(let start, let maxSpeed, let next):
            // Parti de l'arrêt mais resté au pas : ce n'est pas un départ, on réarme ici.
            if maxSpeed < Self.launchSpeed, now.speed < Self.launchSpeed, now.time - start > Self.maxCreep {
                standing = .armed(time: now.time, speed: now.speed)
                return
            }
            guard let before,
                  now.time - before.time <= Self.maxGap,
                  now.time - start <= Self.maxDuration,
                  now.speed >= maxSpeed - Self.cancelDrop
            else {
                standing = .idle
                return
            }
            standing = .running(start: start, maxSpeed: max(maxSpeed, now.speed), next: next)
            checkStandingTargets(from: before, to: now)
        }
    }

    /// Enregistre les seuils franchis entre deux points consécutifs.
    private mutating func checkStandingTargets(from a: Point, to b: Point) {
        guard case .running(let start, let maxSpeed, var next) = standing else { return }
        let targets = SpeedInterval.standing
        while next < targets.count {
            let interval = targets[next]
            let target = Double(interval.to)
            guard a.speed < target, b.speed >= target else { break }
            let time = Self.crossing(of: target, from: a, to: b) - start
            guard time >= interval.minPlausibleTime else {
                standing = .idle
                return
            }
            record(interval, time)
            next += 1
        }
        standing = next < targets.count ? .running(start: start, maxSpeed: maxSpeed, next: next) : .idle
    }

    // MARK: Reprise lancée

    private mutating func updateRolling(from before: Point?, to now: Point) {
        guard let before, now.time - before.time <= Self.maxGap else {
            rolling = nil
            return
        }

        if var run = rolling {
            guard now.time - run.start <= Self.maxDuration, now.speed >= run.maxSpeed - Self.cancelDrop else {
                rolling = nil
                return
            }
            run.maxSpeed = max(run.maxSpeed, now.speed)
            rolling = run
            checkRollingTargets(from: before, to: now)
        } else if before.speed < SpeedInterval.rollingStart, now.speed >= SpeedInterval.rollingStart {
            // La reprise part de l'instant où 50 km/h est franchi en accélérant.
            let start = Self.crossing(of: SpeedInterval.rollingStart, from: before, to: now)
            rolling = Rolling(start: start, maxSpeed: now.speed, next: 0)
            checkRollingTargets(from: before, to: now)
        }
    }

    private mutating func checkRollingTargets(from a: Point, to b: Point) {
        guard var run = rolling else { return }
        let targets = SpeedInterval.rolling
        while run.next < targets.count {
            let interval = targets[run.next]
            let target = Double(interval.to)
            guard a.speed < target, b.speed >= target else { break }
            let time = Self.crossing(of: target, from: a, to: b) - run.start
            guard time >= interval.minPlausibleTime else {
                rolling = nil
                return
            }
            record(interval, time)
            run.next += 1
        }
        rolling = run.next < targets.count ? run : nil
    }

    /// Instant où la vitesse atteint `target`, par interpolation linéaire.
    private static func crossing(of target: Double, from a: Point, to b: Point) -> TimeInterval {
        let span = b.speed - a.speed
        guard span > 0 else { return b.time }
        let ratio = min(1, max(0, (target - a.speed) / span))
        return a.time + ratio * (b.time - a.time)
    }
}
