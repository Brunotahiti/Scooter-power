import Foundation

/// Unité d'une plage chronométrée.
public enum SpeedUnit: String, Sendable, Codable, Hashable {
    case kmh
    case mph

    public var symbol: String { self == .kmh ? "km/h" : "mph" }
}

/// Une plage de vitesse chronométrée, en km/h ou en mph.
public struct SpeedInterval: Hashable, Sendable, Codable {
    public static let kmPerMile = 1.609344

    public let from: Int
    public let to: Int
    public let unit: SpeedUnit

    public init(from: Int, to: Int, unit: SpeedUnit = .kmh) {
        self.from = from
        self.to = to
        self.unit = unit
    }

    public static let zeroTo30 = SpeedInterval(from: 0, to: 30)
    public static let zeroTo50 = SpeedInterval(from: 0, to: 50)
    public static let zeroTo80 = SpeedInterval(from: 0, to: 80)
    public static let zeroTo100 = SpeedInterval(from: 0, to: 100)
    public static let fiftyTo90 = SpeedInterval(from: 50, to: 90)
    public static let fiftyTo100 = SpeedInterval(from: 50, to: 100)

    public static let zeroTo20mph = SpeedInterval(from: 0, to: 20, unit: .mph)
    public static let zeroTo30mph = SpeedInterval(from: 0, to: 30, unit: .mph)
    public static let zeroTo50mph = SpeedInterval(from: 0, to: 50, unit: .mph)
    public static let zeroTo60mph = SpeedInterval(from: 0, to: 60, unit: .mph)
    public static let thirtyTo50mph = SpeedInterval(from: 30, to: 50, unit: .mph)
    public static let thirtyTo60mph = SpeedInterval(from: 30, to: 60, unit: .mph)

    /// Plages en km/h, dans l'ordre d'affichage.
    public static let metric: [SpeedInterval] = [
        .zeroTo30, .zeroTo50, .zeroTo80, .zeroTo100, .fiftyTo90, .fiftyTo100,
    ]
    /// Plages en mph, dans l'ordre d'affichage (0–60 mph : la référence anglo-saxonne).
    public static let imperial: [SpeedInterval] = [
        .zeroTo20mph, .zeroTo30mph, .zeroTo50mph, .zeroTo60mph, .thirtyTo50mph, .thirtyTo60mph,
    ]
    /// Toutes les plages mesurées : les deux séries le sont en même temps.
    public static let all: [SpeedInterval] = metric + imperial

    /// Plages affichées dans l'unité choisie.
    public static func shown(for units: UnitSystem) -> [SpeedInterval] {
        units == .metric ? metric : imperial
    }

    /// Plage la plus longue en départ arrêté : 0–100 km/h ou 0–60 mph.
    public static func flagship(for units: UnitSystem) -> SpeedInterval {
        units == .metric ? .zeroTo100 : .zeroTo60mph
    }

    public var label: String { "\(from)–\(to)" }
    /// « 0–50 km/h » ou « 0–60 mph ».
    public var fullLabel: String { label + " " + unit.symbol }

    public var fromKmh: Double { unit == .kmh ? Double(from) : Double(from) * Self.kmPerMile }
    public var toKmh: Double { unit == .kmh ? Double(to) : Double(to) * Self.kmPerMile }

    /// En dessous, le temps supposerait plus de 1 g d'accélération moyenne
    /// (35 km/h par seconde) : c'est un saut GPS, pas une mesure.
    var minPlausibleTime: TimeInterval { (toKmh - fromKmh) / 35 }

    // L'unité n'est écrite que pour les plages en mph : les données des
    // versions précédentes, toutes en km/h, se relisent telles quelles.
    private enum CodingKeys: String, CodingKey { case from, to, unit }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = try container.decode(Int.self, forKey: .from)
        to = try container.decode(Int.self, forKey: .to)
        unit = try container.decodeIfPresent(SpeedUnit.self, forKey: .unit) ?? .kmh
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        if unit != .kmh { try container.encode(unit, forKey: .unit) }
    }
}

/// Une mesure terminée : la plage et son temps en secondes.
public struct SprintResult: Sendable, Equatable {
    public let interval: SpeedInterval
    public let time: TimeInterval
    /// Instant du départ de la mesure, sur l'horloge des positions GPS.
    public let start: TimeInterval
}

/// Chronomètre les accélérations : départs arrêtés (0–30, 0–50, 0–80, 0–100 km/h)
/// et reprises lancées (50–90, 50–100 km/h), et en même temps les plages en mph
/// (0–20, 0–30, 0–50, 0–60, 30–50, 30–60 mph).
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

    /// Une série de plages (km/h ou mph), avec ses propres mesures en cours.
    private struct Lane: Sendable {
        /// Départs arrêtés, par vitesse d'arrivée croissante.
        let standingTargets: [SpeedInterval]
        /// Reprises lancées, par vitesse d'arrivée croissante ; toutes partent de `rollingStart`.
        let rollingTargets: [SpeedInterval]
        /// Vitesse de départ des reprises (km/h).
        let rollingStart: Double
        var standing = Standing.idle
        var rolling: Rolling?

        init(_ intervals: [SpeedInterval]) {
            standingTargets = intervals.filter { $0.from == 0 }.sorted { $0.toKmh < $1.toKmh }
            rollingTargets = intervals.filter { $0.from != 0 }.sorted { $0.toKmh < $1.toKmh }
            rollingStart = rollingTargets.first?.fromKmh ?? .infinity
        }
    }

    /// Série principale (km/h) puis série en mph.
    private var lanes: [Lane] = [Lane(SpeedInterval.metric), Lane(SpeedInterval.imperial)]
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
        lanes.contains { lane in
            if case .running = lane.standing { return true }
            return false
        }
    }

    /// Une reprise lancée est en cours de mesure.
    public var isRolling: Bool { lanes.contains { $0.rolling != nil } }

    /// Temps écoulé depuis le départ arrêté en cours.
    public func runElapsed(at now: TimeInterval) -> TimeInterval? {
        for lane in lanes {
            if case .running(let start, _, _) = lane.standing { return max(0, now - start) }
        }
        return nil
    }

    /// Temps écoulé de la mesure en cours : le départ arrêté s'il y en a un,
    /// sinon la reprise.
    public func activeElapsed(at now: TimeInterval) -> TimeInterval? {
        if let elapsed = runElapsed(at: now) { return elapsed }
        guard let rolling = lanes.compactMap(\.rolling).first else { return nil }
        return max(0, now - rolling.start)
    }

    /// Abandonne les mesures en cours ; les temps déjà obtenus sont conservés.
    public mutating func cancelRun() {
        for index in lanes.indices {
            lanes[index].standing = .idle
            lanes[index].rolling = nil
        }
    }

    // MARK: - Mesure

    public mutating func add(timestamp: TimeInterval, speedKmh: Double) {
        guard timestamp.isFinite, speedKmh.isFinite, speedKmh >= 0 else { return }
        if let previous, timestamp <= previous.time { return }
        let before = previous
        let now: Point = (timestamp, speedKmh)
        previous = now

        for index in lanes.indices {
            updateRolling(lane: index, from: before, to: now)
            updateStanding(lane: index, from: before, to: now)
        }
    }

    private mutating func record(_ interval: SpeedInterval, _ time: TimeInterval, start: TimeInterval) {
        lastTimes[interval] = time
        bestTimes[interval] = min(bestTimes[interval] ?? time, time)
        results.append(SprintResult(interval: interval, time: time, start: start))
    }

    // MARK: Départ arrêté

    private mutating func updateStanding(lane i: Int, from before: Point?, to now: Point) {
        if now.speed < Self.standstillSpeed {
            lanes[i].standing = .armed(time: now.time, speed: now.speed)
            return
        }

        switch lanes[i].standing {
        case .idle:
            return

        case .armed(let restTime, let restSpeed):
            guard now.time - restTime <= Self.maxGap else {
                lanes[i].standing = .idle
                return
            }
            // Toujours au pas : le point de départ suit le scooter.
            if restSpeed >= Self.standstillSpeed, now.speed < Self.launchSpeed {
                lanes[i].standing = .armed(time: now.time, speed: now.speed)
                return
            }
            let rest: Point = (restTime, restSpeed)
            let start = Self.crossing(of: Self.standstillSpeed, from: rest, to: now)
            lanes[i].standing = .running(start: start, maxSpeed: now.speed, next: 0)
            checkStandingTargets(lane: i, from: rest, to: now)

        case .running(let start, let maxSpeed, let next):
            // Parti de l'arrêt mais resté au pas : ce n'est pas un départ, on réarme ici.
            if maxSpeed < Self.launchSpeed, now.speed < Self.launchSpeed, now.time - start > Self.maxCreep {
                lanes[i].standing = .armed(time: now.time, speed: now.speed)
                return
            }
            guard let before,
                  now.time - before.time <= Self.maxGap,
                  now.time - start <= Self.maxDuration,
                  now.speed >= maxSpeed - Self.cancelDrop
            else {
                lanes[i].standing = .idle
                return
            }
            lanes[i].standing = .running(start: start, maxSpeed: max(maxSpeed, now.speed), next: next)
            checkStandingTargets(lane: i, from: before, to: now)
        }
    }

    /// Enregistre les seuils franchis entre deux points consécutifs.
    private mutating func checkStandingTargets(lane i: Int, from a: Point, to b: Point) {
        guard case .running(let start, let maxSpeed, var next) = lanes[i].standing else { return }
        let targets = lanes[i].standingTargets
        while next < targets.count {
            let interval = targets[next]
            let target = interval.toKmh
            guard a.speed < target, b.speed >= target else { break }
            let time = Self.crossing(of: target, from: a, to: b) - start
            guard time >= interval.minPlausibleTime else {
                lanes[i].standing = .idle
                return
            }
            record(interval, time, start: start)
            next += 1
        }
        lanes[i].standing = next < targets.count ? .running(start: start, maxSpeed: maxSpeed, next: next) : .idle
    }

    // MARK: Reprise lancée

    private mutating func updateRolling(lane i: Int, from before: Point?, to now: Point) {
        guard let before, now.time - before.time <= Self.maxGap else {
            lanes[i].rolling = nil
            return
        }

        if var run = lanes[i].rolling {
            guard now.time - run.start <= Self.maxDuration, now.speed >= run.maxSpeed - Self.cancelDrop else {
                lanes[i].rolling = nil
                return
            }
            run.maxSpeed = max(run.maxSpeed, now.speed)
            lanes[i].rolling = run
            checkRollingTargets(lane: i, from: before, to: now)
        } else if before.speed < lanes[i].rollingStart, now.speed >= lanes[i].rollingStart {
            // La reprise part de l'instant où sa vitesse de départ (50 km/h, 30 mph) est franchie en accélérant.
            let start = Self.crossing(of: lanes[i].rollingStart, from: before, to: now)
            lanes[i].rolling = Rolling(start: start, maxSpeed: now.speed, next: 0)
            checkRollingTargets(lane: i, from: before, to: now)
        }
    }

    private mutating func checkRollingTargets(lane i: Int, from a: Point, to b: Point) {
        guard var run = lanes[i].rolling else { return }
        let targets = lanes[i].rollingTargets
        while run.next < targets.count {
            let interval = targets[run.next]
            let target = interval.toKmh
            guard a.speed < target, b.speed >= target else { break }
            let time = Self.crossing(of: target, from: a, to: b) - run.start
            guard time >= interval.minPlausibleTime else {
                lanes[i].rolling = nil
                return
            }
            record(interval, time, start: run.start)
            run.next += 1
        }
        lanes[i].rolling = run.next < targets.count ? run : nil
    }

    /// Instant où la vitesse atteint `target`, par interpolation linéaire.
    private static func crossing(of target: Double, from a: Point, to b: Point) -> TimeInterval {
        let span = b.speed - a.speed
        guard span > 0 else { return b.time }
        let ratio = min(1, max(0, (target - a.speed) / span))
        return a.time + ratio * (b.time - a.time)
    }
}
