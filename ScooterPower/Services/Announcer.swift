import AVFoundation
import Foundation

/// Annonces vocales, entendues dans le casque (intercom Bluetooth) ou par le
/// haut-parleur : records battus, temps d'accélération, alerte de vitesse,
/// chute détectée. La musique en cours baisse le temps de l'annonce.
@MainActor
final class Announcer: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Announcer()

    private let synthesizer = AVSpeechSynthesizer()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Prononce `text` dans la langue de l'app. `urgent` passe outre le réglage
    /// (alerte de chute) et coupe l'annonce en cours.
    func say(_ text: String, urgent: Bool = false) {
        guard urgent || AppSettings.shared.voiceEnabled else { return }
        if urgent { synthesizer.stopSpeaking(at: .immediate) }
        activateSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AppLanguage.current == .french ? "fr-FR" : "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.02
        utterance.volume = 1
        synthesizer.speak(utterance)
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synthesizer.isSpeaking else { return }
            // Rend le son aux autres apps (musique, GPS).
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
