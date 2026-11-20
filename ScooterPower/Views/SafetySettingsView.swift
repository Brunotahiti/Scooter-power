import ContactsUI
import SwiftUI
import ScooterCore
import UIKit

/// Réglages de sécurité : détection de chute et contacts d'urgence, annonces vocales.
struct SafetySettingsSection: View {
    private let settings = AppSettings.shared

    private var crashEnabled: Binding<Bool> {
        Binding(get: { settings.crashDetectionEnabled }, set: { value in
            settings.setCrashDetectionEnabled(value)
            if value { CrashAlarm.requestNotificationPermission() }
        })
    }

    private var silentMode: Binding<Bool> {
        Binding(get: { settings.crashSilentMode }, set: { settings.setCrashSilentMode($0) })
    }

    private var voiceEnabled: Binding<Bool> {
        Binding(get: { settings.voiceEnabled }, set: { settings.setVoiceEnabled($0) })
    }

    var body: some View {
        Section {
            Toggle(L("Détection de chute"), isOn: crashEnabled)
            if settings.crashDetectionEnabled {
                ForEach(settings.emergencyContacts) { contact in
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(Theme.orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: contact.name)
                            Text(verbatim: contact.phone)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .onDelete { settings.removeEmergencyContacts(at: $0) }
                if settings.emergencyContacts.count < AppSettings.maxEmergencyContacts {
                    Button {
                        ContactPickerPresenter.shared.present { name, phone in
                            settings.addEmergencyContact(EmergencyContact(name: name, phone: phone))
                        }
                    } label: {
                        Label(L("Ajouter un contact d'urgence"), systemImage: "plus.circle.fill")
                    }
                }
                NavigationLink {
                    LiveShareView()
                } label: {
                    Label(L("Position en direct pour mes proches"), systemImage: "location.fill.viewfinder")
                }
                Toggle(L("Mode réglage (sans alarme)"), isOn: silentMode)
                NavigationLink {
                    CrashLogView()
                } label: {
                    LabeledContent(L("Journal des alertes"), value: String(CrashLog.shared.entries.count))
                }
            }
        } header: {
            Text(L("Sécurité"))
        } footer: {
            Text(L("Après une chute probable, l'iPhone sonne et affiche un compte à rebours de 30 secondes. Sans réponse, un SMS avec votre position est prêt à partir vers vos contacts : iOS demande de toucher Envoyer."))
        }

        Section {
            Toggle(L("Annonces vocales"), isOn: voiceEnabled)
            Button {
                Announcer.shared.say(L("Nouveau record ! 0 à 100 kilomètres-heure en 6,2 secondes."), urgent: true)
            } label: {
                Label(L("Écouter un exemple"), systemImage: "speaker.wave.2.fill")
            }
        } header: {
            Text(L("Voix"))
        } footer: {
            Text(L("Records battus, chronos et alerte de vitesse annoncés dans votre casque (intercom Bluetooth) ou par le haut-parleur. La musique baisse pendant l'annonce."))
        }
    }
}

/// Journal des alertes de chute : vraies chutes, fausses alertes et alertes
/// notées en mode réglage, avec ce qui les a déclenchées.
struct CrashLogView: View {
    private let log = CrashLog.shared
    @State private var confirmClear = false

    var body: some View {
        List {
            if log.entries.isEmpty {
                Text(L("Aucune alerte pour l'instant."))
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(log.entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.date, format: .dateTime.day().month().hour().minute())
                            .font(.headline)
                        Spacer()
                        Text(outcomeText(entry.outcome))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(outcomeColor(entry.outcome))
                    }
                    if let trigger = entry.trigger {
                        Text(verbatim: details(trigger, response: entry.responseSeconds))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            if !log.entries.isEmpty {
                Section {
                    ShareLink(item: log.report) {
                        Label(L("Envoyer le journal"), systemImage: "square.and.arrow.up")
                    }
                    Button(L("Effacer le journal"), role: .destructive) { confirmClear = true }
                } footer: {
                    Text(L("Le journal ne contient aucune position. Il aide à régler la détection : envoyez-le au support après une fausse alerte."))
                }
            }
        }
        .navigationTitle(L("Journal des alertes"))
        .confirmationDialog(L("Effacer le journal ?"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button(L("Effacer"), role: .destructive) { log.clear() }
        }
    }

    private func outcomeText(_ outcome: CrashLogEntry.Outcome) -> String {
        switch outcome {
        case .pending: return L("Sans réponse")
        case .fine: return L("Fausse alerte")
        case .alerted: return L("Secours prévenus")
        case .silent: return L("Mode réglage")
        }
    }

    private func outcomeColor(_ outcome: CrashLogEntry.Outcome) -> Color {
        switch outcome {
        case .pending, .alerted: return Theme.red
        case .fine: return Theme.orange
        case .silent: return Theme.cyan
        }
    }

    private func details(_ trigger: CrashDetector.Trigger, response: Double?) -> String {
        let reason: String = trigger.reason == .laidDown ? L("Scooter couché") : L("Choc puis arrêt")
        let units = AppSettings.shared.units
        var parts: [String] = [
            reason,
            Formatters.decimal(trigger.peakG, digits: 1) + " g",
            Formatters.decimal(trigger.tiltDegrees, digits: 0) + "°",
            Formatters.decimal(units.speed(fromKmh: trigger.speedBeforeKmh), digits: 0) + " " + units.speedUnit,
        ]
        if let response { parts.append(Formatters.decimal(response, digits: 0) + " s") }
        return parts.joined(separator: " · ")
    }
}

/// Sélecteur de contacts d'iOS, limité aux numéros de téléphone. Aucune
/// autorisation d'accès aux contacts n'est nécessaire.
/// Présenté directement par UIKit : placé dans une feuille SwiftUI, ce
/// sélecteur (qui tourne dans un processus à part) se referme aussitôt.
@MainActor
final class ContactPickerPresenter: NSObject, CNContactPickerDelegate {
    static let shared = ContactPickerPresenter()
    private var onPick: ((String, String) -> Void)?

    func present(onPick: @escaping (String, String) -> Void) {
        guard let top = Self.topViewController() else { return }
        self.onPick = onPick
        let picker = CNContactPickerViewController()
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        // Toucher un contact ouvre sa fiche : on choisit ensuite le numéro.
        picker.predicateForSelectionOfContact = NSPredicate(value: false)
        picker.delegate = self
        top.present(picker, animated: true)
    }

    nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        guard let number = contactProperty.value as? CNPhoneNumber else { return }
        let contact: CNContact = contactProperty.contact
        let name: String = CNContactFormatter.string(from: contact, style: .fullName) ?? number.stringValue
        let phone: String = number.stringValue
        Task { @MainActor in
            self.onPick?(name, phone)
            self.onPick = nil
        }
    }

    nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        Task { @MainActor in self.onPick = nil }
    }

    /// L'écran affiché au premier plan (la feuille des Réglages, ici).
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top: UIViewController? = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
