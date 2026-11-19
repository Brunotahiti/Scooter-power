import Foundation
import SwiftData
import ScooterCore

/// Un trajet terminé, tel qu'il est conservé dans l'historique.
@Model
final class TripRecord {
    /// Nombre maximal de points de tracé conservés par trajet.
    static let maxRoutePoints = 2000

    var startDate: Date
    var distanceMeters: Double
    var maxSpeedKmh: Double
    var averageSpeedKmh: Double
    var peakAcceleration: Double
    var maxLeanLeftDegrees: Double
    var maxLeanRightDegrees: Double
    var movingDuration: Double
    var totalDuration: Double
    var best50: Double?
    var best80: Double?
    // Ajoutés après la première version : facultatifs, pour que les trajets
    // déjà enregistrés restent lisibles.
    var best30: Double?
    var best50to90: Double?
    var best50to100: Double?
    var best100: Double?
    /// Meilleurs temps sur les plages en mph (« 0-60 » → secondes), encodés en JSON ;
    /// absents des trajets faits avant la version qui les mesure.
    var imperialTimesData: Data?
    /// Scooter du garage utilisé pour ce trajet (`Scooter.uid`) ; absent des trajets anciens.
    var scooterID: String?
    /// Nom donné par le pilote ; sans nom, le trajet est désigné par sa date.
    var name: String?
    /// Course contre un ghost pendant ce trajet (`GhostRaceResult` en JSON).
    @Attribute(.externalStorage) var raceData: Data?
    /// Résultat de cette course, lisible sans décoder `raceData` : vrai gagnée, faux perdue.
    var raceWon: Bool?
    /// Configuration du scooter pendant ce trajet ; absente des trajets anciens.
    var setupName: String?
    /// Poussée le long du tracé allégé, encodée en JSON ; absente des trajets anciens.
    var thrustData: Data?
    /// Meilleures accélérations et pic de poussée, encodés en JSON ; absents des trajets anciens.
    var highlightsData: Data?
    /// Vitesse, poussée et inclinaison le long du tracé allégé, encodées en JSON,
    /// pour revoir le trajet ; absentes des trajets anciens.
    @Attribute(.externalStorage) var replayData: Data?
    /// Tracé allégé, encodé en JSON.
    @Attribute(.externalStorage) var routeData: Data

    init(startDate: Date, summary: TripSummary, route: [Coordinate], setupName: String? = nil,
         thrust: [Double] = [], highlights: [TripHighlight] = [], replay: [ReplayPoint] = []) {
        self.startDate = startDate
        self.setupName = setupName
        // Tracé et poussée sont allégés ensemble pour rester alignés.
        let kept: [Int] = RouteSimplifier.indices(count: route.count, maxPoints: Self.maxRoutePoints)
        if thrust.count == route.count {
            self.thrustData = try? JSONEncoder().encode(kept.map { thrust[$0] })
        }
        if replay.count == route.count {
            self.replayData = try? JSONEncoder().encode(kept.map { replay[$0] })
        }
        self.highlightsData = try? JSONEncoder().encode(highlights)
        self.distanceMeters = summary.distanceMeters
        self.maxSpeedKmh = summary.maxSpeedKmh
        self.averageSpeedKmh = summary.averageSpeedKmh
        self.peakAcceleration = summary.peakAcceleration
        self.maxLeanLeftDegrees = summary.maxLeanLeftDegrees
        self.maxLeanRightDegrees = summary.maxLeanRightDegrees
        self.movingDuration = summary.movingDuration
        self.totalDuration = summary.totalDuration
        self.best30 = summary.best(.zeroTo30)
        self.best50 = summary.best(.zeroTo50)
        self.best80 = summary.best(.zeroTo80)
        self.best50to90 = summary.best(.fiftyTo90)
        self.best50to100 = summary.best(.fiftyTo100)
        self.best100 = summary.best(.zeroTo100)
        var imperial: [String: Double] = [:]
        for interval in SpeedInterval.imperial {
            if let time = summary.best(interval) { imperial[Self.key(interval)] = time }
        }
        self.imperialTimesData = imperial.isEmpty ? nil : try? JSONEncoder().encode(imperial)
        let light = RouteSimplifier.downsample(route, maxPoints: Self.maxRoutePoints)
        self.routeData = (try? JSONEncoder().encode(light)) ?? Data()
    }

    private var bestTimes: [SpeedInterval: TimeInterval] {
        var times: [SpeedInterval: TimeInterval] = [:]
        times[.zeroTo30] = best30
        times[.zeroTo50] = best50
        times[.zeroTo80] = best80
        times[.fiftyTo90] = best50to90
        times[.fiftyTo100] = best50to100
        times[.zeroTo100] = best100
        if let imperialTimesData,
           let imperial = try? JSONDecoder().decode([String: Double].self, from: imperialTimesData) {
            for interval in SpeedInterval.imperial {
                if let time = imperial[Self.key(interval)], time.isFinite, time > 0 { times[interval] = time }
            }
        }
        return times
    }

    private static func key(_ interval: SpeedInterval) -> String {
        "\(interval.from)-\(interval.to)"
    }

    var summary: TripSummary {
        TripSummary(
            distanceMeters: distanceMeters,
            maxSpeedKmh: maxSpeedKmh,
            averageSpeedKmh: averageSpeedKmh,
            peakAcceleration: peakAcceleration,
            maxLeanLeftDegrees: maxLeanLeftDegrees,
            maxLeanRightDegrees: maxLeanRightDegrees,
            movingDuration: movingDuration,
            totalDuration: totalDuration,
            bestTimes: bestTimes)
    }

    var thrust: [Double] {
        guard let thrustData else { return [] }
        return (try? JSONDecoder().decode([Double].self, from: thrustData)) ?? []
    }

    var highlights: [TripHighlight] {
        guard let highlightsData else { return [] }
        return (try? JSONDecoder().decode([TripHighlight].self, from: highlightsData)) ?? []
    }

    var race: GhostRaceResult? {
        guard let raceData else { return nil }
        return try? JSONDecoder().decode(GhostRaceResult.self, from: raceData)
    }

    var replayPoints: [ReplayPoint] {
        guard let replayData else { return [] }
        return (try? JSONDecoder().decode([ReplayPoint].self, from: replayData)) ?? []
    }

    /// Le trajet prêt à être revu ; à vitesse moyenne constante pour les trajets anciens.
    var replay: TripReplay {
        TripReplay(route: route, points: replayPoints, averageSpeedKmh: averageSpeedKmh)
    }

    /// Le trajet tel qu'il est envoyé à un ami.
    func shared(riderName: String) -> SharedTrip {
        SharedTrip(
            riderName: riderName, setupName: setupName ?? "", date: startDate, summary: summary,
            route: route, points: replayPoints)
    }

    var route: [Coordinate] {
        (try? JSONDecoder().decode([Coordinate].self, from: routeData)) ?? []
    }

    /// Date et heure de départ, dans la langue de l'interface.
    var title: String {
        AppDates.dateTime(startDate)
    }

    /// Le nom du trajet s'il en a un, sinon sa date.
    var displayTitle: String {
        guard let name, !name.isEmpty else { return title }
        return name
    }

    /// Vrai si le pilote a nommé ce trajet.
    var isNamed: Bool { !(name ?? "").isEmpty }
}
