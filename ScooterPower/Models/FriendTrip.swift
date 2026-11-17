import Foundation
import SwiftData
import ScooterCore

/// Trajet reçu d'un ami, à revoir sur la carte.
@Model
final class FriendTrip {
    var riderName: String
    var setupName: String
    var startDate: Date
    var receivedDate: Date
    var distanceMeters: Double
    var maxSpeedKmh: Double
    var averageSpeedKmh: Double
    var totalDuration: Double
    /// Le fichier reçu, tel quel : le trajet est relu à partir de lui.
    @Attribute(.externalStorage) var fileData: Data

    init(trip: SharedTrip, data: Data, receivedDate: Date = Date()) {
        self.riderName = trip.riderName
        self.setupName = trip.setupName
        self.startDate = trip.date
        self.receivedDate = receivedDate
        self.distanceMeters = trip.distanceMeters
        self.maxSpeedKmh = trip.maxSpeedKmh
        self.averageSpeedKmh = trip.averageSpeedKmh
        self.totalDuration = trip.totalDuration
        self.fileData = data
    }

    var shared: SharedTrip? {
        try? SharedTrip(data: fileData)
    }

    /// Pseudo affiché, ou « Pilote » s'il est vide.
    var displayName: String {
        riderName.isEmpty ? L("Pilote") : riderName
    }

    var title: String {
        AppDates.dateTime(startDate)
    }
}
