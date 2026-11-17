import Foundation
import SwiftData
import ScooterCore

/// Balade de groupe enregistrée : le trajet de chaque pilote, sur une horloge commune.
@Model
final class GroupRideRecord {
    var startDate: Date
    var riderCount: Int
    /// Noms des pilotes, pour la liste de l'historique.
    var riderNames: [String]
    /// Trajets des pilotes, encodés en JSON.
    @Attribute(.externalStorage) var tracksData: Data

    init(startDate: Date, tracks: [GroupRideTrack]) {
        self.startDate = startDate
        self.riderCount = tracks.count
        self.riderNames = tracks.map { $0.isMe ? L("Moi") : ($0.name.isEmpty ? L("Pilote") : $0.name) }
        self.tracksData = (try? JSONEncoder().encode(tracks)) ?? Data()
    }

    var tracks: [GroupRideTrack] {
        (try? JSONDecoder().decode([GroupRideTrack].self, from: tracksData)) ?? []
    }

    var title: String {
        AppDates.dateTime(startDate)
    }

    /// Pistes prêtes à rejouer : la mienne d'abord, chacune avec la couleur qu'elle avait pendant la balade.
    var replayTracks: [ReplayTrack] {
        let sorted: [GroupRideTrack] = tracks.sorted { $0.isMe && !$1.isMe }
        return sorted.map { track in
            ReplayTrack(
                id: track.isMe ? "mine" : "rider-" + track.riderID,
                name: track.isMe ? L("Moi") : (track.name.isEmpty ? L("Pilote") : track.name),
                replay: track.replay,
                color: GroupRideView.color(track.colorIndex))
        }
    }
}
