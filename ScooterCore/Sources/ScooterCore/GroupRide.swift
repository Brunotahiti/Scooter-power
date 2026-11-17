import Foundation

/// Lien d'invitation à une balade de groupe, affiché en QR code :
/// `scooterpower://ride?id=ABCD2345`.
public struct RideLink: Sendable, Equatable {
    public static let host = "ride"
    /// Alphabet sans caractères ambigus (ni 0/O, ni 1/I/L).
    static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    public static let idLength = 8

    public let rideID: String

    public init(rideID: String) {
        self.rideID = rideID
    }

    /// Nouvelle balade, avec un identifiant aléatoire.
    public static func random() -> RideLink {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> RideLink {
        let id = String((0..<idLength).map { _ in alphabet.randomElement(using: &generator)! })
        return RideLink(rideID: id)
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = PerformanceCard.scheme
        components.host = Self.host
        components.queryItems = [URLQueryItem(name: "id", value: rideID)]
        return components.url ?? URL(string: "\(PerformanceCard.scheme)://\(Self.host)?id=\(rideID)")!
    }

    /// Lit un lien d'invitation ; `nil` s'il n'en est pas un ou si l'identifiant est invalide.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == PerformanceCard.scheme, url.host?.lowercased() == Self.host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name == "id" })?.value
        else { return nil }
        let id = raw.uppercased()
        guard id.count == Self.idLength, id.allSatisfy({ Self.alphabet.contains($0) }) else { return nil }
        self.rideID = id
    }
}

/// Liste des pilotes d'une balade, dans l'ordre d'arrivée. L'ordre donne la
/// couleur de chacun. Au plus `capacity` pilotes.
public struct GroupRoster: Sendable, Equatable, Codable {
    public static let capacity = 5

    public enum JoinError: Error, Equatable {
        case full
    }

    public private(set) var members: [String]

    public init(members: [String] = []) {
        // Doublons retirés, ordre conservé, capacité respectée.
        var seen: Set<String> = []
        var kept: [String] = []
        for member in members where !member.isEmpty && !seen.contains(member) {
            seen.insert(member)
            kept.append(member)
        }
        self.members = Array(kept.prefix(Self.capacity))
    }

    public var isFull: Bool { members.count >= Self.capacity }

    /// Ajoute le pilote s'il n'y est pas déjà ; erreur si la balade est complète.
    public mutating func join(_ riderID: String) throws {
        guard !members.contains(riderID) else { return }
        guard !isFull else { throw JoinError.full }
        members.append(riderID)
    }

    public mutating func leave(_ riderID: String) {
        members.removeAll { $0 == riderID }
    }

    /// Couleur du pilote : sa place dans la liste (0 à 4), ou `nil` s'il n'en fait pas partie.
    public func colorIndex(of riderID: String) -> Int? {
        members.firstIndex(of: riderID)
    }
}

/// Dernière position connue d'un pilote de la balade.
public struct RiderPosition: Sendable, Equatable, Codable {
    public var riderID: String
    public var name: String
    public var coordinate: Coordinate
    public var speedKmh: Double
    /// Cap en degrés, 0 = nord.
    public var heading: Double
    public var leanDegrees: Double
    public var acceleration: Double
    public var updatedAt: Date

    public init(riderID: String, name: String, coordinate: Coordinate, speedKmh: Double, heading: Double,
                leanDegrees: Double, acceleration: Double, updatedAt: Date) {
        self.riderID = riderID
        self.name = name
        self.coordinate = coordinate
        self.speedKmh = speedKmh
        self.heading = heading
        self.leanDegrees = leanDegrees
        self.acceleration = acceleration
        self.updatedAt = updatedAt
    }

    /// Délai au-delà duquel le pilote est affiché « hors ligne ».
    public static let staleAfter: TimeInterval = 45

    public func isStale(at now: Date) -> Bool {
        now.timeIntervalSince(updatedAt) > Self.staleAfter
    }
}

/// Traînée récente d'un pilote, pour la dessiner derrière lui sur la carte.
public struct RiderTrail: Sendable, Equatable {
    public static let maxPoints = 80
    /// Écart minimal entre deux points gardés, en mètres.
    public static let minSpacing: Double = 5

    public private(set) var points: [Coordinate] = []

    public init() {}

    public mutating func add(_ coordinate: Coordinate) {
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return }
        if let last = points.last, TripStatistics.haversine(last, coordinate) < Self.minSpacing { return }
        points.append(coordinate)
        if points.count > Self.maxPoints {
            points.removeFirst(points.count - Self.maxPoints)
        }
    }
}

/// Trajet d'un pilote pendant une balade de groupe, pour la revoir ensuite.
public struct GroupRideTrack: Sendable, Equatable, Codable {
    public var riderID: String
    public var name: String
    public var colorIndex: Int
    public var isMe: Bool
    public var route: [Coordinate]
    /// Temps comptés depuis le début de la balade, communs à tous les pilotes.
    public var points: [ReplayPoint]

    public init(riderID: String, name: String, colorIndex: Int, isMe: Bool,
                route: [Coordinate], points: [ReplayPoint]) {
        self.riderID = riderID
        self.name = name
        self.colorIndex = colorIndex
        self.isMe = isMe
        self.route = route
        self.points = points
    }

    public var replay: TripReplay {
        TripReplay(route: route, points: points, averageSpeedKmh: 0, absoluteTimes: true)
    }
}

/// Enregistre les positions reçues pendant une balade de groupe.
public struct GroupRideRecorder: Sendable {
    /// Points gardés par pilote au plus (environ 2 h à un point toutes les 3 s).
    public static let maxPointsPerRider = 2500

    public private(set) var start: Date?
    private var tracks: [String: GroupRideTrack] = [:]
    private var order: [String] = []
    private var lastUpdate: [String: Date] = [:]

    public init() {}

    /// Ajoute une position ; ignorée si elle n'est pas plus récente que la précédente du même pilote.
    public mutating func add(_ position: RiderPosition, colorIndex: Int, isMe: Bool) {
        guard position.coordinate.latitude.isFinite, position.coordinate.longitude.isFinite else { return }
        if let last = lastUpdate[position.riderID], position.updatedAt <= last { return }
        lastUpdate[position.riderID] = position.updatedAt
        let origin: Date = start ?? position.updatedAt
        start = origin
        var track: GroupRideTrack = tracks[position.riderID] ?? GroupRideTrack(
            riderID: position.riderID, name: position.name, colorIndex: colorIndex, isMe: isMe, route: [], points: [])
        if !position.name.isEmpty { track.name = position.name }
        track.colorIndex = colorIndex
        track.route.append(position.coordinate)
        track.points.append(ReplayPoint(
            time: max(0, position.updatedAt.timeIntervalSince(origin)), speedKmh: max(0, position.speedKmh),
            acceleration: position.acceleration, leanDegrees: position.leanDegrees))
        if track.route.count > Self.maxPointsPerRider {
            track.route.removeFirst()
            track.points.removeFirst()
        }
        if tracks[position.riderID] == nil { order.append(position.riderID) }
        tracks[position.riderID] = track
    }

    /// Pilotes avec au moins deux points, dans l'ordre d'arrivée.
    public var recordedTracks: [GroupRideTrack] {
        order.compactMap { tracks[$0] }.filter { $0.route.count > 1 }
    }

    public var isEmpty: Bool { recordedTracks.isEmpty }
}
