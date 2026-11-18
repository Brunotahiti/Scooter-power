import SwiftUI
import ScooterCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared

    /// Pages d'assistance et de confidentialité dans la langue de l'app.
    private var supportURL: URL? {
        URL(string: settings.language == .french
            ? "https://brunotahiti.github.io/Scooter-power/"
            : "https://brunotahiti.github.io/Scooter-power/en/")
    }

    private var privacyURL: URL? {
        URL(string: settings.language == .french
            ? "https://brunotahiti.github.io/Scooter-power/confidentialite.html"
            : "https://brunotahiti.github.io/Scooter-power/en/privacy.html")
    }

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
    @State private var riderDraft = ""

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
                languageSection
                unitsSection
                SafetySettingsSection()
                alertSection
                aboutSection
            }
            .navigationTitle(L("Réglages"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Fermer")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Nom de la configuration du scooter, appliqué aux prochains trajets.
    private var setupSection: some View {
        Section {
            TextField(L("Origine"), text: $setupDraft)
                .submitLabel(.done)
                .onSubmit { settings.setCurrentSetup(setupDraft) }
                .onChange(of: setupDraft) { _, value in
                    settings.setCurrentSetup(value)
                }
            TextField(L("Pseudo"), text: $riderDraft)
                .textInputAutocapitalization(.words)
                .onChange(of: riderDraft) { _, value in
                    settings.setRiderName(value)
                }
        } header: {
            Text(L("Configuration du scooter"))
        } footer: {
            Text(L("Chaque trajet est enregistré avec ce nom. Changez-le après une modification du scooter : la page Statistiques compare alors les performances avant et après. Le pseudo apparaît sur la carte de performances que vous partagez."))
        }
        .onAppear {
            setupDraft = settings.currentSetup
            riderDraft = settings.riderName
        }
    }

    private var language: Binding<AppLanguage> {
        Binding(get: { settings.language }, set: { settings.setLanguage($0) })
    }

    /// Langue de l'app, indépendante de celle de l'iPhone.
    private var languageSection: some View {
        Section {
            Picker(L("Langue"), selection: language) {
                ForEach(AppLanguage.allCases) { option in
                    Text(verbatim: option.nativeName).tag(option)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(L("Langue"))
        } footer: {
            Text(L("Les demandes d'autorisation et l'écran verrouillé changent de langue au prochain lancement de l'app."))
        }
    }

    private var unitsSection: some View {
        Section {
            Picker(L("Unités"), selection: units) {
                Text(L("Kilomètres")).tag(UnitSystem.metric)
                Text(L("Miles")).tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)
        } header: {
            Text(L("Unités"))
        } footer: {
            Text(L("En miles, la vitesse, la distance et les temps d'accélération passent en mph : 0–60 mph, 30–50 mph… Les deux séries sont mesurées à chaque trajet."))
        }
    }

    private var alertSection: some View {
        Section {
            Toggle(L("Alerter au-dessus d'un seuil"), isOn: alertEnabled)
            if settings.speedAlertEnabled {
                Stepper(value: alertThreshold, in: settings.speedAlertDisplayRange, step: AppSettings.speedAlertStep) {
                    Text(thresholdText)
                        .monospacedDigit()
                }
            }
        } header: {
            Text(L("Alerte de vitesse"))
        } footer: {
            Text(L("Le compteur passe au rouge et le téléphone vibre quand le seuil est dépassé. L'alerte ne fonctionne que lorsque l'app est à l'écran."))
        }
    }

    private var aboutSection: some View {
        Section {
            if let url = supportURL {
                Link(L("Assistance"), destination: url)
            }
            if let url = privacyURL {
                Link(L("Politique de confidentialité"), destination: url)
            }
            LabeledContent(L("Version"), value: version)
        } header: {
            Text(L("À propos"))
        }
    }
}

#Preview {
    SettingsView()
}
