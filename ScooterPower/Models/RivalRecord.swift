import Foundation
import SwiftData
import ScooterCore

/// Carte de performances reçue d'un autre pilote.
@Model
final class RivalRecord {
    var riderName: String
    var setupName: String
    var cardDate: Date
    var receivedDate: Date
    /// Le lien d'origine : la carte est relue à partir de lui.
    var link: String

    init(card: PerformanceCard, receivedDate: Date = Date()) {
        self.riderName = card.riderName
        self.setupName = card.setupName
        self.cardDate = card.date
        self.receivedDate = receivedDate
        self.link = card.link.absoluteString
    }

    var card: PerformanceCard? {
        guard let url = URL(string: link) else { return nil }
        return try? PerformanceCard(link: url)
    }

    /// Pseudo affiché, ou « Pilote » s'il est vide.
    var displayName: String {
        riderName.isEmpty ? L("Pilote") : riderName
    }
}
