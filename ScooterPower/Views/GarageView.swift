import SwiftData
import SwiftUI
import ScooterCore

/// Garage : les scooters, leur kilométrage, l'entretien et les pleins.
struct GarageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Scooter.createdAt) private var scooters: [Scooter]
    @Query private var trips: [TripRecord]
    @Query private var tasks: [MaintenanceTask]
    @State private var showAdd = false
    private let settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            List {
                if scooters.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(L("Ajoutez votre scooter"), systemImage: "scooter")
                                .font(.headline)
                            Text(L("Le kilométrage avance tout seul avec vos trajets. Scooter Power vous prévient avant la vidange, la révision ou les pneus."))
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                            Button(L("Ajouter un scooter")) { showAdd = true }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.cyan)
                        }
                        .padding(.vertical, 6)
                    }
                } else {
                    Section(L("Mes scooters")) {
                        ForEach(scooters) { scooter in
                            NavigationLink {
                                ScooterDetailView(scooter: scooter)
                            } label: {
                                row(scooter)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("Garage"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Fermer")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(L("Ajouter un scooter"))
                }
            }
            .sheet(isPresented: $showAdd) {
                AddScooterSheet { name, model, km in add(name: name, model: model, km: km) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ scooter: Scooter) -> some View {
        let km: Double = scooter.odometerKm(trips: trips)
        let due: Int = tasks.filter { $0.scooterID == scooter.uid && $0.status(currentKm: km).state != .ok }.count
        let isCurrent: Bool = currentID == scooter.uid
        return HStack(spacing: 12) {
            Image(systemName: "scooter")
                .font(.title2)
                .foregroundStyle(isCurrent ? Theme.cyan : Theme.textSecondary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(scooter.displayName).font(.headline)
                    if isCurrent {
                        Text(L("Actuel"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.cyan.opacity(0.2), in: Capsule())
                            .foregroundStyle(Theme.cyan)
                    }
                }
                Text(GarageFormat.odometer(km))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if due > 0 {
                Label(String(due), systemImage: "wrench.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.orange)
            }
        }
    }

    /// Le scooter courant : celui choisi, sinon le premier.
    private var currentID: String? {
        scooters.first { $0.uid == settings.currentScooterID }?.uid ?? scooters.first?.uid
    }

    private func add(name: String, model: String, km: Double) {
        let scooter = Scooter(name: name, model: model, startOdometerKm: km)
        modelContext.insert(scooter)
        // Entretiens courants, comptés à partir d'aujourd'hui.
        for kind in MaintenanceKind.allCases where kind != .custom {
            modelContext.insert(MaintenanceTask(scooterID: scooter.uid, kind: kind, lastDoneKm: km))
        }
        if scooters.isEmpty || settings.currentScooterID == nil {
            settings.setCurrentScooter(scooter.uid)
        }
        try? modelContext.save()
        LocalNotifier.requestPermission()
    }
}

/// Fiche d'un scooter : kilométrage, entretiens et consommation.
struct ScooterDetailView: View {
    @Bindable var scooter: Scooter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var trips: [TripRecord]
    @Query private var allTasks: [MaintenanceTask]
    @Query(sort: \FuelEntry.date, order: .reverse) private var allFuel: [FuelEntry]
    @State private var editing: MaintenanceTask?
    @State private var showFuel = false
    @State private var showAddTask = false
    @State private var confirmDelete = false
    @State private var newTaskTitle = ""
    private let settings = AppSettings.shared

    private var km: Double { scooter.odometerKm(trips: trips) }
    private var tasks: [MaintenanceTask] {
        allTasks.filter { $0.scooterID == scooter.uid }
            .sorted { $0.status(currentKm: km).progress > $1.status(currentKm: km).progress }
    }
    private var fuel: [FuelEntry] { allFuel.filter { $0.scooterID == scooter.uid } }
    private var isCurrent: Bool {
        settings.currentScooterID == scooter.uid
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Compteur"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(GarageFormat.odometer(km))
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    if !scooter.model.isEmpty {
                        Text(scooter.model).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
                if isCurrent {
                    Label(L("Utilisé pour les prochains trajets"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.cyan)
                } else {
                    Button(L("Utiliser ce scooter"), systemImage: "scooter") {
                        settings.setCurrentScooter(scooter.uid)
                    }
                }
            }

            Section {
                ForEach(tasks) { task in
                    MaintenanceRow(task: task, currentKm: km) {
                        task.lastDoneKm = km
                        task.lastDoneDate = Date()
                        try? modelContext.save()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editing = task }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(tasks[index]) }
                    try? modelContext.save()
                }
                Button(L("Ajouter un entretien"), systemImage: "plus") { showAddTask = true }
            } header: {
                Text(L("Entretien"))
            } footer: {
                Text(L("Touchez une ligne pour modifier l'intervalle. « Fait » remet le compteur à zéro."))
            }

            Section {
                if let economy = FuelEconomy.litersPer100Km(fuel.map { FuelFill(odometerKm: $0.odometerKm, liters: $0.liters) }) {
                    HStack {
                        Text(L("Consommation moyenne"))
                        Spacer()
                        Text(GarageFormat.economy(economy))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Theme.cyan)
                    }
                } else {
                    Text(L("Faites le plein à ras bord et notez-le deux fois de suite pour connaître la consommation."))
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(fuel) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date, style: .date)
                            Text(GarageFormat.odometer(entry.odometerKm))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text(GarageFormat.volume(entry.liters))
                            .font(.body.monospacedDigit())
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(fuel[index]) }
                    try? modelContext.save()
                }
                Button(L("Noter un plein"), systemImage: "fuelpump.fill") { showFuel = true }
            } header: {
                Text(L("Carburant"))
            }

            Section {
                TextField(L("Nom"), text: $scooter.name)
                TextField(L("Marque et modèle"), text: $scooter.model)
            } header: {
                Text(L("Scooter"))
            }

            Section {
                Button(L("Supprimer ce scooter"), role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(scooter.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
        .sheet(item: $editing) { task in
            MaintenanceEditSheet(task: task, currentKm: km)
        }
        .sheet(isPresented: $showFuel) {
            FuelSheet(currentKm: km) { liters, odometer, price in
                modelContext.insert(FuelEntry(scooterID: scooter.uid, liters: liters, odometerKm: odometer, price: price))
                try? modelContext.save()
            }
        }
        .alert(L("Nouvel entretien"), isPresented: $showAddTask) {
            TextField(L("Par exemple : bougie"), text: $newTaskTitle)
            Button(L("Ajouter")) { addTask() }
            Button(L("Annuler"), role: .cancel) { newTaskTitle = "" }
        }
        .confirmationDialog(L("Supprimer ce scooter ?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("Supprimer"), role: .destructive) { delete() }
        } message: {
            Text(L("Ses entretiens et ses pleins seront supprimés. Les trajets restent dans l'historique."))
        }
    }

    private func addTask() {
        let title: String = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        newTaskTitle = ""
        guard !title.isEmpty else { return }
        modelContext.insert(MaintenanceTask(scooterID: scooter.uid, kind: .custom, title: title, lastDoneKm: km))
        try? modelContext.save()
    }

    private func delete() {
        for task in allTasks where task.scooterID == scooter.uid { modelContext.delete(task) }
        for entry in allFuel where entry.scooterID == scooter.uid { modelContext.delete(entry) }
        if settings.currentScooterID == scooter.uid { settings.setCurrentScooter(nil) }
        modelContext.delete(scooter)
        try? modelContext.save()
        dismiss()
    }
}

/// Une ligne d'entretien : barre d'avancement colorée selon l'échéance.
private struct MaintenanceRow: View {
    let task: MaintenanceTask
    let currentKm: Double
    let onDone: () -> Void

    var body: some View {
        let status: MaintenanceStatus = task.status(currentKm: currentKm)
        let color: Color = Self.color(status.state)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: task.kind.icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.displayTitle).font(.body.weight(.semibold))
                    Text(GarageFormat.remaining(status))
                        .font(.caption)
                        .foregroundStyle(status.state == .ok ? Theme.textSecondary : color)
                }
                Spacer()
                Button(L("Fait"), action: onDone)
                    .buttonStyle(.bordered)
                    .tint(status.state == .ok ? Theme.textSecondary : color)
                    .font(.caption.weight(.bold))
            }
            ProgressView(value: status.progress)
                .tint(color)
        }
        .padding(.vertical, 4)
    }

    static func color(_ state: MaintenanceState) -> Color {
        switch state {
        case .ok: return Theme.cyan
        case .soon: return Theme.orange
        case .due: return Theme.red
        }
    }
}

/// Réglage de l'intervalle et du dernier entretien.
private struct MaintenanceEditSheet: View {
    @Bindable var task: MaintenanceTask
    let currentKm: Double
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var distanceText = ""
    @State private var lastText = ""
    @State private var months = 12
    @State private var usesMonths = true

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Intervalle")) {
                    HStack {
                        Text(L("Tous les"))
                        TextField(String("0"), text: $distanceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text(AppSettings.shared.units.distanceUnit)
                    }
                    Toggle(L("Limite de temps"), isOn: $usesMonths)
                    if usesMonths {
                        Stepper(L("\(String(months)) mois"), value: $months, in: 1...60)
                    }
                }
                Section(L("Dernier entretien")) {
                    HStack {
                        Text(L("Au compteur"))
                        TextField(String("0"), text: $lastText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text(AppSettings.shared.units.distanceUnit)
                    }
                    DatePicker(L("Date"), selection: $task.lastDoneDate, in: ...Date(), displayedComponents: .date)
                }
            }
            .navigationTitle(task.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("OK")) { save() }
                }
            }
            .onAppear {
                distanceText = task.intervalKm.map { GarageFormat.inputValue(km: $0) } ?? ""
                lastText = GarageFormat.inputValue(km: task.lastDoneKm)
                usesMonths = task.intervalMonths != nil
                months = task.intervalMonths ?? 12
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let distance: Double? = GarageFormat.km(fromInput: distanceText)
        task.intervalKm = (distance ?? 0) > 0 ? distance : nil
        task.intervalMonths = usesMonths ? months : nil
        if let last = GarageFormat.km(fromInput: lastText) {
            task.lastDoneKm = min(last, currentKm)
        }
        try? modelContext.save()
        dismiss()
    }
}

/// Ajout d'un scooter.
private struct AddScooterSheet: View {
    let onAdd: (String, String, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var model = ""
    @State private var odometer = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("Nom (facultatif)"), text: $name)
                    TextField(L("Marque et modèle"), text: $model)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text(L("Le modèle sert aussi aux classements entre scooters identiques."))
                }
                Section {
                    HStack {
                        TextField(L("Kilométrage actuel"), text: $odometer)
                            .keyboardType(.numberPad)
                        Text(AppSettings.shared.units.distanceUnit)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } footer: {
                    Text(L("Lisez le compteur de votre scooter. Ensuite, chaque trajet enregistré l'augmente."))
                }
            }
            .navigationTitle(L("Nouveau scooter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Ajouter")) {
                        onAdd(name, model.trimmingCharacters(in: .whitespacesAndNewlines),
                              GarageFormat.km(fromInput: odometer) ?? 0)
                        dismiss()
                    }
                    .disabled(model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Saisie d'un plein.
private struct FuelSheet: View {
    let currentKm: Double
    let onAdd: (Double, Double, Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var volume = ""
    @State private var odometer = ""
    @State private var price = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(L("Quantité"), text: $volume)
                            .keyboardType(.decimalPad)
                        Text(GarageFormat.volumeUnit).foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        TextField(L("Compteur"), text: $odometer)
                            .keyboardType(.numberPad)
                        Text(AppSettings.shared.units.distanceUnit).foregroundStyle(Theme.textSecondary)
                    }
                    TextField(L("Prix payé (facultatif)"), text: $price)
                        .keyboardType(.decimalPad)
                } footer: {
                    Text(L("Remplissez le réservoir à ras bord à chaque fois : la consommation sera exacte."))
                }
            }
            .navigationTitle(L("Plein"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Ajouter")) {
                        if let liters = GarageFormat.liters(fromInput: volume) {
                            onAdd(liters, GarageFormat.km(fromInput: odometer) ?? currentKm, GarageFormat.number(price))
                        }
                        dismiss()
                    }
                    .disabled(GarageFormat.liters(fromInput: volume) == nil)
                }
            }
            .onAppear { odometer = GarageFormat.inputValue(km: currentKm) }
        }
        .preferredColorScheme(.dark)
    }
}

/// Conversions et textes du garage, dans les unités choisies.
@MainActor
enum GarageFormat {
    private static var units: UnitSystem { AppSettings.shared.units }
    private static let litersPerGallon = 3.785411784

    /// Distance affichée par kilomètre (1 ou 0,621).
    private static var perKm: Double { units.distance(fromMeters: 1000) }

    static func odometer(_ km: Double) -> String {
        Formatters.decimal(km * perKm, digits: 0) + " " + units.distanceUnit
    }

    static func inputValue(km: Double) -> String {
        String(Int((km * perKm).rounded()))
    }

    static func number(_ text: String) -> Double? {
        let cleaned: String = text.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")
        guard let value = Double(cleaned), value.isFinite, value >= 0 else { return nil }
        return value
    }

    static func km(fromInput text: String) -> Double? {
        number(text).map { $0 / perKm }
    }

    static var volumeUnit: String { units == .metric ? "L" : "gal" }

    static func liters(fromInput text: String) -> Double? {
        guard let value = number(text), value > 0 else { return nil }
        return units == .metric ? value : value * litersPerGallon
    }

    static func volume(_ liters: Double) -> String {
        let value: Double = units == .metric ? liters : liters / litersPerGallon
        return Formatters.decimal(value, digits: 1) + " " + volumeUnit
    }

    static func economy(_ litersPer100Km: Double) -> String {
        if units == .metric {
            return Formatters.decimal(litersPer100Km, digits: 1) + " L/100 km"
        }
        return Formatters.decimal(FuelEconomy.mpg(fromLitersPer100Km: litersPer100Km), digits: 0) + " mpg"
    }

    static func remaining(_ status: MaintenanceStatus) -> String {
        var parts: [String] = []
        if let km = status.remainingKm {
            let value: String = Formatters.decimal(abs(km) * perKm, digits: 0) + " " + units.distanceUnit
            parts.append(km >= 0 ? L("dans \(value)") : L("dépassé de \(value)"))
        }
        if let days = status.remainingDays {
            if days >= 0 {
                parts.append(days > 60 ? L("\(String(days / 30)) mois") : L("\(String(days)) j"))
            } else {
                parts.append(L("en retard de \(String(-days)) j"))
            }
        }
        return parts.joined(separator: " · ")
    }
}
