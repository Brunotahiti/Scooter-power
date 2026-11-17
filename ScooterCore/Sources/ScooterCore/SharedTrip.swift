import Foundation

/// Un trajet envoyé à un ami : tracé, vitesses, poussée, inclinaison et
/// chiffres clés, dans un fichier « .scooterpower » (JSON).
/// Il ne contient aucun identifiant : seulement le pseudo choisi.
public struct SharedTrip: Sendable, Equatable, Codable {
    public static let fileExtension = "scooterpower"
    public static let currentVersion = 1
    /// Nombre maximal de points, pour garder un fichier léger (environ 50 Ko).
    public static let maxPoints = 900
    public static let maxNameLength = 30

    public var version: Int
    public var riderName: String
    public var setupName: String
    public var date: Date
    public var distanceMeters: Double
    public var maxSpeedKmh: Double
    public var averageSpeedKmh: Double
    public var totalDuration: TimeInterval
    public var route: [Coordinate]
    public var points: [ReplayPoint]

    public enum DecodingError: Error {
        case unreadable
        case newerVersion
        case empty
    }

    /// Construit le trajet à partager ; tracé et points sont allégés ensemble.
    public init(riderName: String, setupName: String, date: Date, summary: TripSummary,
                route: [Coordinate], points: [ReplayPoint]) {
        self.version = Self.currentVersion
        self.riderName = String(riderName.prefix(Self.maxNameLength))
        self.setupName = String(setupName.prefix(Self.maxNameLength))
        self.date = date
        self.distanceMeters = summary.distanceMeters
        self.maxSpeedKmh = summary.maxSpeedKmh
        self.averageSpeedKmh = summary.averageSpeedKmh
        self.totalDuration = summary.totalDuration
        let kept: [Int] = RouteSimplifier.indices(count: route.count, maxPoints: Self.maxPoints)
        self.route = kept.map { Self.rounded(route[$0]) }
        self.points = points.count == route.count ? kept.map { Self.rounded(points[$0]) } : []
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public init(data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let trip = try? decoder.decode(SharedTrip.self, from: data) else { throw DecodingError.unreadable }
        guard trip.version <= Self.currentVersion else { throw DecodingError.newerVersion }
        let finite = trip.route.allSatisfy { $0.latitude.isFinite && $0.longitude.isFinite }
        guard trip.route.count > 1, finite else { throw DecodingError.empty }
        self = trip
        riderName = String(riderName.prefix(Self.maxNameLength))
        setupName = String(setupName.prefix(Self.maxNameLength))
        if points.count != route.count { points = [] }
    }

    public var replay: TripReplay {
        TripReplay(route: route, points: points, averageSpeedKmh: averageSpeedKmh)
    }

    /// Nom du fichier à envoyer, sans caractères spéciaux.
    public func fileName(title: String) -> String {
        GPXExporter.fileName(for: title) + "." + Self.fileExtension
    }

    // 6 décimales (≈ 10 cm) et vitesses au dixième suffisent largement.
    private static func rounded(_ c: Coordinate) -> Coordinate {
        Coordinate(latitude: (c.latitude * 1e6).rounded() / 1e6, longitude: (c.longitude * 1e6).rounded() / 1e6)
    }

    private static func rounded(_ p: ReplayPoint) -> ReplayPoint {
        ReplayPoint(
            time: (p.time * 10).rounded() / 10,
            speedKmh: (p.speedKmh * 10).rounded() / 10,
            acceleration: (p.acceleration * 10).rounded() / 10,
            leanDegrees: p.leanDegrees.rounded())
    }
}
