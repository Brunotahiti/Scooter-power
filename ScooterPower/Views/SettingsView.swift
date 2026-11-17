import SwiftUI
import ScooterCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = AppSettings.shared

    /// Pages d'assistance et de confidentialité dans la langue de l'app.
    private static var isFrench: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("fr") ?? false
    }

    private static var supportURL: URL? {
        URL(string: isFrench
            ? "https://brunotahiti.github.io/Scooter-power/"
            : "https://brunotahiti.github.io/Scooter-power/en/")
    }

    private static var privacyURL: URL? {
        URL(string: isFrench
            ? "https://brunotahiti.github.io/Scooter-power/confidentialite.html"
            : "https://brunotahiti.github.io/Scooter-power/en/privacy.html")
    }

    /// Nom de la langue de l'app, dans cette langue (« Français », « English »).
    private var languageName: String {
        let code: String = Bundle.main.preferredLocalizations.first ?? "en"
        let name: String = Locale(identifier: code).localizedString(forLanguageCode: code) ?? code
        return name.prefix(1).uppercased() + name.dropFirst()
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
            TextField("Pseudo", text: $riderDraft)
                .textInputAutocapitalization(.words)
                .onChange(of: riderDraft) { _, value in
                    settings.setRiderName(value)
                }
        } header: {
            Text("Configuration du scooter")
        } footer: {
            Text("Chaque trajet est enregistré avec ce nom. Changez-le après une modification du scooter : la page Statistiques compare alors les performances avant et après. Le pseudo apparaît sur la carte de performances que vous partagez.")
        }
        .onAppear {
            setupDraft = settings.currentSetup
            riderDraft = settings.riderName
        }
    }

    /// La langue se choisit dans les Réglages d'iOS, page de l'app.
    private var languageSection: some View {
        Section {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                LabeledContent("Langue", value: languageName)
            }
        } footer: {
            Text("Français ou anglais. Ouvre les Réglages de l'iPhone, rubrique Langue.")
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
            Text("En miles, la vitesse, la distance et les temps d'accélération passent en mph : 0–60 mph, 30–50 mph… Les deux séries sont mesurées à chaque trajet.")
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
