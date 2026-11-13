import SwiftUI
import ScooterCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared

    private static let supportURL = URL(string: "https://brunotahiti.github.io/Scooter-power/")
    private static let privacyURL = URL(string: "https://brunotahiti.github.io/Scooter-power/confidentialite.html")

    private var units: Binding<UnitSystem> {
        Binding(get: { settings.units }, set: { settings.setUnits($0) })
    }

    private var alertEnabled: Binding<Bool> {
        Binding(get: { settings.speedAlertEnabled }, set: { settings.setSpeedAlertEnabled($0) })
    }

    private var alertThreshold: Binding<Double> {
        Binding(get: { settings.speedAlertDisplayValue }, set: { settings.setSpeedAlertDisplayValue($0) })
    }

    @State private var setupDraft = ""

    private var thresholdText: String {
        let value: String = Formatters.decimal(settings.speedAlertDisplayValue, digits: 0)
        return L("Seuil : \(value) \(settings.units.speedUnit)")
    }

    private var version: String {
        let short: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "--"
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "--"
        return short + " (" + build + ")"
    }

    var body: some View {
        NavigationStack {
            Form {
                setupSection
                unitsSection
                alertSection
                aboutSection
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Nom de la configuration du scooter, appliqué aux prochains trajets.
    private var setupSection: some View {
        Section {
            TextField("Origine", text: $setupDraft)
                .submitLabel(.done)
                .onSubmit { settings.setCurrentSetup(setupDraft) }
                .onChange(of: setupDraft) { _, value in
                    settings.setCurrentSetup(value)
                }
        } header: {
            Text("Configuration du scooter")
        } footer: {
            Text("Chaque trajet est enregistré avec ce nom. Changez-le après une modification du scooter : la page Statistiques compare alors les performances avant et après.")
        }
        .onAppear {
            setupDraft = settings.currentSetup
        }
    }

    private var unitsSection: some View {
        Section {
            Picker("Unités", selection: units) {
                Text("Kilomètres").tag(UnitSystem.metric)
                Text("Miles").tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Unités")
        } footer: {
            Text("Les temps d'accélération restent mesurés en km/h.")
        }
    }

    private var alertSection: some View {
        Section {
            Toggle("Alerter au-dessus d'un seuil", isOn: alertEnabled)
            if settings.speedAlertEnabled {
                Stepper(value: alertThreshold, in: settings.speedAlertDisplayRange, step: AppSettings.speedAlertStep) {
                    Text(thresholdText)
                        .monospacedDigit()
                }
            }
        } header: {
            Text("Alerte de vitesse")
        } footer: {
            Text("Le compteur passe au rouge et le téléphone vibre quand le seuil est dépassé. L'alerte ne fonctionne que lorsque l'app est à l'écran.")
        }
    }

    private var aboutSection: some View {
        Section {
            if let url = Self.supportURL {
                Link("Assistance", destination: url)
            }
            if let url = Self.privacyURL {
                Link("Politique de confidentialité", destination: url)
            }
            LabeledContent("Version", value: version)
        } header: {
            Text("À propos")
        }
    }
}

#Preview {
    SettingsView()
}
