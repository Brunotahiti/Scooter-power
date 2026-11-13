import SwiftUI
import ScooterCore

/// Page de statistiques de performance : chiffres clés, accélérations
/// (record, moyenne, nombre de mesures) et comparaison de deux
/// configurations du scooter avec l'écart en pourcentage.
struct StatsView: View {
    let trips: [TripRecord]

    /// Configuration affichée ; `nil` pour toutes.
    @State private var filter: String?
    @State private var baseline = ""
    @State private var modified = ""

    private static func setup(of trip: TripRecord) -> String {
        AppSettings.cleaned(trip.setupName ?? "")
    }

    /// Configurations présentes dans l'historique, de la plus ancienne à la plus récente.
    private var setups: [String] {
        var names: [String] = []
        for trip in trips.sorted(by: { $0.startDate < $1.startDate }) {
            let name: String = Self.setup(of: trip)
            if !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    private func stats(for setup: String?) -> PerformanceStats {
        var summaries: [TripSummary] = []
        for trip in trips where setup == nil || Self.setup(of: trip) == setup {
            summaries.append(trip.summary)
        }
        return PerformanceStats(trips: summaries)
    }

    var body: some View {
        let names: [String] = setups
        let current: PerformanceStats = stats(for: filter)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if trips.isEmpty {
                    empty
                } else {
                    if names.count > 1 {
                        filterPicker(names)
                    }
                    StatsHero(stats: current)
                    StatsAccelerations(stats: current)
                    StatsTotals(stats: current)
                    if names.count > 1 {
                        comparison(names)
                    } else {
                        comparisonHint
                    }
                }
            }
            .padding(16)
        }
        .background(backdrop.ignoresSafeArea())
        .navigationTitle("Statistiques")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Par défaut : la première configuration contre la plus récente.
            if baseline.isEmpty, let first = names.first { baseline = first }
            if modified.isEmpty, let last = names.last { modified = last }
        }
    }

    private var backdrop: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Color(hex: 0x3A1508).opacity(0.8), Color.clear],
                center: UnitPoint(x: 0.5, y: 0), startRadius: 10, endRadius: 380)
        }
    }

    private var empty: some View {
        ContentUnavailableView(
            "Aucune statistique",
            systemImage: "chart.bar.fill",
            description: Text("Vos performances apparaîtront ici après votre premier trajet."))
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    // MARK: - Filtre

    private func filterPicker(_ names: [String]) -> some View {
        HStack {
            Text("Configuration")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Picker("Configuration", selection: $filter) {
                Text("Toutes").tag(String?.none)
                ForEach(names, id: \.self) { name in
                    Text(verbatim: name).tag(String?.some(name))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.orange)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .cardStyle(tint: Theme.orange)
    }

    // MARK: - Comparaison de configurations

    private var comparisonHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatsSectionTitle(text: L("Avant / après"))
            Text("Après une modification du scooter, donnez un nouveau nom à sa configuration dans les réglages. Vos prochains trajets seront comparés aux précédents, avec l'écart en pourcentage.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func comparison(_ names: [String]) -> some View {
        let deltas: [StatDelta] = PerformanceComparison.deltas(
            baseline: stats(for: baseline), modified: stats(for: modified))
        var shown: [StatDelta] = []
        for delta in deltas where delta.baseline != nil || delta.modified != nil {
            shown.append(delta)
        }
        return VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: L("Avant / après"))
            HStack(spacing: 10) {
                setupPicker(title: L("Avant"), selection: $baseline, names: names, tint: Theme.cyan)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.orange)
                setupPicker(title: L("Après"), selection: $modified, names: names, tint: Theme.orange)
            }
            VStack(spacing: 0) {
                ForEach(shown.indices, id: \.self) { index in
                    StatsDeltaRow(delta: shown[index])
                    if index < shown.count - 1 {
                        Rectangle()
                            .fill(Theme.cardBorder)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .cardStyle(tint: Theme.orange)
        }
    }

    private func setupPicker(title: String, selection: Binding<String>, names: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .italic()
                .foregroundStyle(tint)
            Picker(title, selection: selection) {
                ForEach(names, id: \.self) { name in
                    Text(verbatim: name).tag(name)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(tint: tint)
    }
}

/// `StatsView` présenté seul, avec sa propre barre de navigation.
struct StatsSheet: View {
    let trips: [TripRecord]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StatsView(trips: trips)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Mise en forme des valeurs

private enum StatsFormat {
    static func speed(_ kmh: Double) -> String {
        let units: UnitSystem = AppSettings.shared.units
        return Formatters.decimal(units.speed(fromKmh: kmh), digits: 0)
    }

    static var speedUnit: String { AppSettings.shared.units.speedUnit }

    static func time(_ seconds: TimeInterval) -> String {
        Formatters.decimal(seconds, digits: 1) + " s"
    }

    static func value(_ value: Double?, for metric: StatMetric) -> String {
        guard let value else { return "--" }
        switch metric {
        case .topSpeed, .averageTopSpeed, .overallAverageSpeed:
            return speed(value) + " " + speedUnit
        case .bestPeakAcceleration, .averagePeakAcceleration:
            return Formatters.decimal(value, digits: 1) + " m/s²"
        case .intervalBest, .intervalAverage:
            return time(value)
        case .maxLean:
            return Formatters.decimal(value, digits: 0) + "°"
        }
    }

    static func title(_ metric: StatMetric) -> String {
        switch metric {
        case .topSpeed: return L("Vitesse maximale")
        case .averageTopSpeed: return L("Vitesse max. moyenne")
        case .overallAverageSpeed: return L("Vitesse moyenne")
        case .bestPeakAcceleration: return L("Pic de poussée")
        case .averagePeakAcceleration: return L("Poussée moyenne")
        case .intervalBest(let interval): return L("\(interval.label) km/h · record")
        case .intervalAverage(let interval): return L("\(interval.label) km/h · moyenne")
        case .maxLean: return L("Inclinaison max.")
        }
    }
}

// MARK: - Éléments

/// Titre de section : barre inclinée orange et texte en capitales italiques.
private struct StatsSectionTitle: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Theme.orange)
                .frame(width: 5, height: 20)
                .rotationEffect(.degrees(14))
                .shadow(color: Theme.orange.opacity(0.9), radius: 5)
            Text(verbatim: text.uppercased())
                .font(.system(size: 19, weight: .black))
                .italic()
                .kerning(1)
                .foregroundStyle(Theme.textPrimary)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Les quatre chiffres clés : vitesse et poussée, record et moyenne.
private struct StatsHero: View {
    let stats: PerformanceStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: L("Puissance"))
            HStack(spacing: 10) {
                StatsBigTile(
                    title: L("Vitesse maximale"), value: StatsFormat.speed(stats.topSpeedKmh),
                    unit: StatsFormat.speedUnit, tint: Theme.orange)
                StatsBigTile(
                    title: L("Vitesse max. moyenne"), value: StatsFormat.speed(stats.averageTopSpeedKmh),
                    unit: StatsFormat.speedUnit, tint: Theme.cyan)
            }
            HStack(spacing: 10) {
                StatsBigTile(
                    title: L("Pic de poussée"), value: Formatters.decimal(stats.bestPeakAcceleration, digits: 1),
                    unit: "m/s²", tint: Theme.orange)
                StatsBigTile(
                    title: L("Poussée moyenne"), value: Formatters.decimal(stats.averagePeakAcceleration, digits: 1),
                    unit: "m/s²", tint: Theme.cyan)
            }
        }
    }
}

private struct StatsBigTile: View {
    let title: String
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 40, weight: .black))
                    .italic()
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.6), radius: 8)
                Text(verbatim: unit)
                    .font(.system(size: 16, weight: .heavy))
                    .italic()
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(tint: tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value + " " + unit)
    }
}

/// Tableau des accélérations : record, moyenne et nombre de mesures par plage.
private struct StatsAccelerations: View {
    let stats: PerformanceStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: L("Accélérations"))
            VStack(spacing: 0) {
                header
                ForEach(SpeedInterval.all.indices, id: \.self) { index in
                    Rectangle()
                        .fill(Theme.cardBorder)
                        .frame(height: 1)
                    row(SpeedInterval.all[index])
                }
            }
            .padding(.horizontal, 12)
            .cardStyle(tint: Theme.orange)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(verbatim: "km/h")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Record")
                .frame(width: 74, alignment: .trailing)
            Text("Moyenne")
                .frame(width: 74, alignment: .trailing)
            Text("Mesures")
                .frame(width: 62, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .heavy))
        .italic()
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.vertical, 8)
    }

    private func row(_ interval: SpeedInterval) -> some View {
        let entry: PerformanceStats.IntervalStats? = stats.intervals[interval]
        let best: String = entry.map { StatsFormat.time($0.best) } ?? "--"
        let average: String = entry.map { StatsFormat.time($0.average) } ?? "--"
        let count: String = entry.map { String($0.count) } ?? "0"
        // Régularité : à quel point la moyenne approche le record.
        let consistency: Double = entry.map { $0.average > 0 ? min(1, $0.best / $0.average) : 0 } ?? 0
        return VStack(spacing: 5) {
            HStack(spacing: 6) {
                Text(verbatim: interval.label)
                    .font(.system(size: 18, weight: .black))
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: best)
                    .font(.system(size: 18, weight: .black))
                    .italic()
                    .foregroundStyle(Theme.orange)
                    .frame(width: 74, alignment: .trailing)
                Text(verbatim: average)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.cyan)
                    .frame(width: 74, alignment: .trailing)
                Text(verbatim: count)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 62, alignment: .trailing)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            StatsBar(fraction: consistency)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.vertical, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(interval.label + " km/h")
        .accessibilityValue(L("Record \(best), moyenne \(average), \(count) mesures"))
    }
}

/// Barre fine à segments inclinés, remplie selon `fraction`.
private struct StatsBar: View {
    let fraction: Double

    private static let segments = 30

    var body: some View {
        let lit: Int = Int((min(1, max(0, fraction)) * Double(Self.segments)).rounded())
        return HStack(spacing: 2) {
            ForEach(0..<Self.segments, id: \.self) { index in
                Rectangle()
                    .fill(index < lit ? color(at: index) : Theme.gaugeIdle.opacity(0.45))
                    .frame(height: 5)
            }
        }
    }

    private func color(at index: Int) -> Color {
        let position: Double = Double(index) / Double(Self.segments - 1)
        if position < 0.6 { return Theme.cyan }
        if position < 0.85 { return Theme.orange }
        return Theme.red
    }
}

/// Totaux : trajets, distance, temps de roulage, inclinaison.
private struct StatsTotals: View {
    let stats: PerformanceStats

    private var distance: String {
        let units: UnitSystem = AppSettings.shared.units
        return Formatters.decimal(units.distance(fromMeters: stats.totalDistanceMeters), digits: 0)
            + " " + units.distanceUnit
    }

    private var lean: String {
        Formatters.decimal(max(stats.maxLeanLeftDegrees, stats.maxLeanRightDegrees), digits: 0) + "°"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: L("Totaux"))
            VStack(spacing: 0) {
                line(L("Trajets"), String(stats.tripCount))
                separator
                line(L("Distance"), distance)
                separator
                line(L("Durée de roulage"), Formatters.duration(stats.totalMovingDuration))
                separator
                line(L("Vitesse moyenne"), StatsFormat.speed(stats.overallAverageSpeedKmh) + " " + StatsFormat.speedUnit)
                separator
                line(L("Inclinaison max."), lean)
            }
            .padding(.horizontal, 12)
            .cardStyle()
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Theme.cardBorder)
            .frame(height: 1)
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: title)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(verbatim: value)
                .font(.system(size: 18, weight: .black))
                .italic()
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// Une ligne de la comparaison : valeurs avant et après, et l'écart en pourcentage.
private struct StatsDeltaRow: View {
    let delta: StatDelta

    private var badgeColor: Color {
        switch delta.verdict {
        case .better: return Color(hex: 0x34D058)
        case .worse: return Theme.red
        case .same, .unknown: return Theme.gaugeIdle
        }
    }

    private var badgeText: String {
        guard let percent = delta.percent else { return "--" }
        // Le signe pour cent n'est pas traduit : un « % » dans une clé de traduction
        // serait lu comme un format.
        return Formatters.signed(percent, digits: 0) + " %"
    }

    private var spoken: String {
        switch delta.verdict {
        case .better: return L("mieux")
        case .worse: return L("moins bien")
        case .same: return L("identique")
        case .unknown: return L("non comparable")
        }
    }

    var body: some View {
        let before: String = StatsFormat.value(delta.baseline, for: delta.metric)
        let after: String = StatsFormat.value(delta.modified, for: delta.metric)
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: StatsFormat.title(delta.metric))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 5) {
                    Text(verbatim: before)
                        .foregroundStyle(Theme.cyan)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                    Text(verbatim: after)
                        .foregroundStyle(Theme.orange)
                }
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            Text(verbatim: badgeText)
                .font(.system(size: 17, weight: .black))
                .italic()
                .monospacedDigit()
                .foregroundStyle(delta.verdict == .better || delta.verdict == .worse ? Color.black : Theme.textPrimary)
                .padding(.horizontal, 10)
                .frame(minWidth: 76, minHeight: 30)
                .background(badgeColor, in: Capsule())
                .shadow(color: badgeColor.opacity(0.7), radius: 6)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StatsFormat.title(delta.metric))
        .accessibilityValue(before + ", " + after + ", " + badgeText + ", " + spoken)
    }
}
