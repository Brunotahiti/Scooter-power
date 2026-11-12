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
    /// Tracé allégé, encodé en JSON.
    @Attribute(.externalStorage) var routeData: Data

    init(startDate: Date, summary: TripSummary, route: [Coordinate]) {
        self.startDate = startDate
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
        return times
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

    var route: [Coordinate] {
        (try? JSONDecoder().decode([Coordinate].self, from: routeData)) ?? []
    }

    /// Date et heure de départ, en français.
    var title: String {
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
            .locale(Locale(identifier: "fr_FR"))
        return startDate.formatted(style)
    }
}
