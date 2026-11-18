import AudioToolbox
import Foundation
import ScooterCore
import UIKit
import UserNotifications

/// Chute probable détectée pendant un trajet.
struct CrashAlert: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    /// Dernière position connue, pour le message d'alerte.
    let coordinate: Coordinate?

    /// Lien Plans vers la position, lisible sur n'importe quel téléphone.
    var mapsLink: String? {
        guard let coordinate else { return nil }
        let lat: String = String(format: "%.6f", coordinate.latitude)
        let lon: String = String(format: "%.6f", coordinate.longitude)
        return "https://maps.apple.com/?ll=\(lat),\(lon)&q=\(lat),\(lon)"
    }

    /// Message envoyé aux contacts d'urgence.
    var message: String {
        var text: String = L("Scooter Power a détecté une chute possible. Je ne réponds pas : merci de vérifier que je vais bien.")
        if let mapsLink { text += "\n" + L("Ma position : \(mapsLink)") }
        return text
    }
}

/// Alarme de chute : vibrations et son répétés, notification si l'app n'est
/// pas à l'écran, annonce vocale.
@MainActor
final class CrashAlarm {
    static let shared = CrashAlarm()

    private var timer: Timer?

    func start() {
        stop()
        ring()
        let timer = Timer(timeInterval: 1.2, repeats: true) { _ in
            Task { @MainActor in CrashAlarm.shared.ring() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Announcer.shared.say(L("Chute détectée. Touchez Je vais bien pour annuler l'alerte."), urgent: true)
        if UIApplication.shared.applicationState != .active {
            Self.postNotification()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func ring() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        AudioServicesPlayAlertSound(SystemSoundID(1005))
    }

    /// Autorisation des notifications, demandée quand la surveillance est activée.
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = L("Chute détectée ?")
        content.body = L("Ouvrez Scooter Power pour annuler l'alerte ou prévenir vos contacts.")
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: "crash", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
