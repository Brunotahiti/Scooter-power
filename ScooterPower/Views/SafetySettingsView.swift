import ContactsUI
import SwiftUI

/// Réglages de sécurité : détection de chute et contacts d'urgence, annonces vocales.
struct SafetySettingsSection: View {
    private let settings = AppSettings.shared
    @State private var showPicker = false

    private var crashEnabled: Binding<Bool> {
        Binding(get: { settings.crashDetectionEnabled }, set: { value in
            settings.setCrashDetectionEnabled(value)
            if value { CrashAlarm.requestNotificationPermission() }
        })
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
                        showPicker = true
                    } label: {
                        Label(L("Ajouter un contact d'urgence"), systemImage: "plus.circle.fill")
                    }
                }
            }
        } header: {
            Text(L("Sécurité"))
        } footer: {
            Text(L("Après une chute probable, l'iPhone sonne et affiche un compte à rebours de 30 secondes. Sans réponse, un SMS avec votre position est prêt à partir vers vos contacts : iOS demande de toucher Envoyer."))
        }
        .sheet(isPresented: $showPicker) {
            ContactPicker { name, phone in
                settings.addEmergencyContact(EmergencyContact(name: name, phone: phone))
                showPicker = false
            } onCancel: {
                showPicker = false
            }
            .ignoresSafeArea()
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

/// Sélecteur de contacts d'iOS, limité aux numéros de téléphone. Aucune
/// autorisation d'accès aux contacts n'est nécessaire.
private struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (String, String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.predicateForSelectionOfContact = NSPredicate(value: false)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String, String) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            guard let number = contactProperty.value as? CNPhoneNumber else { return }
            let contact: CNContact = contactProperty.contact
            let name: String = CNContactFormatter.string(from: contact, style: .fullName) ?? number.stringValue
            onPick(name, number.stringValue)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }
    }
}
