import SwiftData
import SwiftUI
import ScooterCore
import UIKit

struct TripScreen: View {
    @State private var model = TripViewModel()
    @State private var showMap = false
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var confirmFinish = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showRecords = false
    @State private var showStats = false
    @State private var showGroupRide = false
    @State private var showGarage = false
    @Query private var scooters: [Scooter]
    @Query private var maintenance: [MaintenanceTask]
    private let settings = AppSettings.shared
    @Environment(\.modelContext) private var modelContext
    /// Tous les trajets enregistrés : la source des records.
    @Query private var history: [TripRecord]
    @Environment(\.openURL) private var openURL
    /// Compacte quand l'iPhone est en paysage.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        layout
            // Changer de langue reconstruit l'écran (le trajet en cours, gardé par `model`, continue).
            .id(settings.language)
            .overlay(alignment: .top) {
                recordBanner
            }
            .animation(.spring(duration: 0.4), value: model.recordBanner)
            .onAppear {
                loadRecords()
                // La balade de groupe lit ma position dans le trajet en cours.
                GroupRideService.shared.positionProvider = { [model] in
                    model.groupPosition(name: AppSettings.shared.riderName)
                }
                GroupRideService.shared.onRideRecorded = { [modelContext] start, tracks in
                    modelContext.insert(GroupRideRecord(startDate: start, tracks: tracks))
                    try? modelContext.save()
                }
            }
            .onChange(of: history.count) { _, _ in
                loadRecords()
            }
            .onChange(of: settings.units) { _, _ in
                model.settingsChanged()
            }
            .onChange(of: settings.language) { _, _ in
                // Textes déjà calculés (vitesses, chronos, records) recalculés dans la nouvelle langue.
                model.settingsChanged()
            }
            .modifier(TripPresentations(
                model: model,
                showMap: $showMap,
                showCamera: $showCamera,
                showCameraUnavailable: $showCameraUnavailable,
                confirmFinish: $confirmFinish,
                showHistory: $showHistory,
                showSettings: $showSettings,
                showRecords: $showRecords,
                showStats: $showStats,
                trips: history))
            .onChange(of: verticalSizeClass) { _, _ in
                // Le téléphone a tourné sur son support : la position verticale a changé.
                model.recalibrate()
            }
            .modifier(CardReceiver(showStats: $showStats, showGroupRide: $showGroupRide))
            .fullScreenCover(isPresented: $showGroupRide) {
                GroupRideView()
            }
            .sheet(isPresented: $showGarage) {
                GarageView()
            }
            .fullScreenCover(item: Binding(get: { model.crashAlert }, set: { if $0 == nil { model.dismissCrashAlert() } })) { alert in
                CrashAlertView(alert: alert) { model.dismissCrashAlert() }
            }
            .onChange(of: model.state) { _, newState in
                if newState == .finished {
                    saveTrip()
                }
            }
            .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var layout: some View {
        if verticalSizeClass == .compact {
            LandscapeTripView(
                model: model,
                onTogglePause: { model.togglePause() },
                onMain: { mainAction() },
                onOpenSettings: { openSettings() },
                onHistory: { showHistory = true },
                onStats: { showStats = true },
                onSettings: { showSettings = true },
                onGroupRide: { showGroupRide = true },
                onGarage: { showGarage = true })
        } else {
            portrait
        }
    }

    private var portrait: some View {
        ScrollView {
            VStack(spacing: 6) {
                gauge
                banners
                speedCards
                tripCards
                AccelerationCard(
                    value: model.accelerationValue,
                    valueText: model.accelerationText,
                    level: model.accelerationLevel)
                AccelerationHistoryCard(history: model.accelerationHistory, peakText: model.peakText)
                sprintCard
                LeanCard(degrees: model.leanDegrees, text: model.leanText, side: model.leanSide)
                if model.isDemo {
                    Text(L("Données d'illustration"))
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 2)
        }
        .background(backdrop.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(
                state: model.state,
                onMap: { showMap = true },
                onTogglePause: { model.togglePause() },
                onMain: { mainAction() },
                onPhoto: { takePhoto() })
        }
    }

    /// Fond sombre avec un halo bleuté derrière le compteur.
    private var backdrop: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Color(hex: 0x0B2A3A).opacity(0.9), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.14), startRadius: 10, endRadius: 330)
        }
    }

    /// Le compteur, avec les commandes posées dans ses coins supérieurs.
    private var gauge: some View {
        ZStack(alignment: .top) {
            SpeedometerView(
                speed: model.speedValue,
                unit: model.speedUnit,
                maxSpeed: model.speedometerMax,
                labelStep: model.speedometerStep,
                isAlert: model.speedAlertActive,
                signalBars: model.state == .idle ? 4 : model.gpsSignalBars,
                acceleration: model.accelerationValue,
                leanDegrees: model.leanDegrees)
            HeaderView(
                state: model.state,
                onHistory: { showHistory = true },
                onStats: { showStats = true },
                onSettings: { showSettings = true },
                onRecalibrate: { model.recalibrate() },
                onGroupRide: { showGroupRide = true },
                onGarage: { showGarage = true })
        }
    }

    @ViewBuilder
    private var banners: some View {
        if model.locationDenied {
            locationDeniedBanner
        }
        if model.gpsWeak {
            banner(icon: "location.slash", text: L("Signal GPS faible"))
        }
    }

    private var sprintCard: some View {
        SprintCard(
            times: model.sprintTexts,
            records: model.recordTexts,
            progress: model.sprintProgress,
            beaten: model.beatenRecords,
            isRunning: model.sprintRunning,
            elapsedText: model.sprintElapsedText)
            // À l'arrêt, toucher la carte ouvre l'écran des records.
            .contentShape(Rectangle())
            .onTapGesture {
                if model.state == .idle {
                    showRecords = true
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(L("Ouvre les records"))
    }

    private var speedCards: some View {
        HStack(spacing: 8) {
            BigStatCard(
                icon: "mountain.2", title: L("Vitesse maximale"),
                value: model.maxSpeedText, unit: model.speedUnit)
            BigStatCard(
                icon: "gauge.with.needle", title: L("Vitesse moyenne"),
                value: model.averageSpeedText, unit: model.speedUnit)
        }
    }

    private var tripCards: some View {
        HStack(spacing: 8) {
            SmallStatCard(icon: "road.lanes", title: L("Distance"), value: model.distanceText)
            SmallStatCard(icon: "triangle", title: L("Altitude"), value: model.altitudeText)
            SmallStatCard(icon: "stopwatch", title: L("Durée de roulage"), value: model.movingDurationText)
        }
    }

    /// Enregistre le trajet qui vient de se terminer dans l'historique.
    private func saveTrip() {
        guard let summary = model.summary, let startDate = model.startDate else { return }
        let record = TripRecord(
            startDate: startDate, summary: summary, route: model.route, setupName: settings.currentSetup,
            thrust: model.thrustTrack, highlights: model.highlights, replay: model.replayTrack)
        let scooter: Scooter? = scooters.first { $0.uid == settings.currentScooterID } ?? scooters.first
        record.scooterID = scooter?.uid
        modelContext.insert(record)
        // Écriture immédiate : sans elle, quitter l'app juste après peut perdre le trajet.
        try? modelContext.save()
        if let scooter {
            MaintenanceReminder.check(scooter: scooter, tasks: maintenance, trips: history + [record])
        }
    }

    @ViewBuilder
    private var recordBanner: some View {
        if let banner = model.recordBanner {
            RecordBannerView(banner: banner)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(banner.id)
        }
    }

    /// Transmet au modèle le meilleur temps de chaque plage sur tout l'historique.
    private func loadRecords() {
        var times: [[SpeedInterval: TimeInterval]] = []
        for trip in history {
            times.append(trip.summary.bestTimes)
        }
        model.setHistoryRecords(RecordBook.best(of: times))
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func mainAction() {
        if model.state == .idle {
            model.start()
        } else {
            confirmFinish = true
        }
    }

    private func takePhoto() {
        if CameraPicker.isAvailable {
            showCamera = true
        } else {
            showCameraUnavailable = true
        }
    }

    private var locationDeniedBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("Scooter Power a besoin de votre position pour mesurer le trajet."), systemImage: "location.slash")
                .font(.system(size: 14))
            Button(L("Ouvrir Réglages")) {
                openSettings()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.cyan)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func banner(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .cardStyle()
    }
}

/// Feuilles, alertes et dialogues de l'écran, communs au portrait et au paysage.
private struct TripPresentations: ViewModifier {
    let model: TripViewModel
    @Binding var showMap: Bool
    @Binding var showCamera: Bool
    @Binding var showCameraUnavailable: Bool
    @Binding var confirmFinish: Bool
    @Binding var showHistory: Bool
    @Binding var showSettings: Bool
    @Binding var showRecords: Bool
    @Binding var showStats: Bool
    /// Tous les trajets enregistrés, pour l'écran des records.
    let trips: [TripRecord]

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showRecords) {
                RecordsSheet(trips: trips)
            }
            .sheet(isPresented: $showStats) {
                StatsSheet(trips: trips)
            }
            .sheet(isPresented: $showMap) {
                MapSheet(
                    route: model.route, thrust: model.thrustTrack, highlights: model.highlights,
                    showsUser: !model.isDemo)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker()
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: summaryPresented) {
                if let summary = model.summary {
                    SummaryView(
                        summary: summary,
                        route: model.route,
                        thrust: model.thrustTrack,
                        highlights: model.highlights,
                        date: model.startDate,
                        recordTimes: recordTimes,
                        trophies: trophies(for: summary),
                        accelerationHistory: model.accelerationHistory,
                        onDone: { model.reset() })
                }
            }
            .confirmationDialog(L("Terminer le trajet ?"), isPresented: $confirmFinish, titleVisibility: .visible) {
                Button(L("Terminer"), role: .destructive) { model.finish() }
                Button(L("Annuler"), role: .cancel) {}
            }
            .alert(L("Appareil photo indisponible"), isPresented: $showCameraUnavailable) {
                Button(L("OK"), role: .cancel) {}
            }
    }

    /// Records battus par le trajet tout juste terminé, face aux trajets précédents.
    private func trophies(for summary: TripSummary) -> [Trophy] {
        var history: [TripSummary] = []
        for trip in trips where trip.startDate != model.startDate {
            history.append(trip.summary)
        }
        // Les deux séries sont mesurées ; seuls les trophées de l'unité affichée sont montrés.
        let displayed: [SpeedInterval] = SpeedInterval.displayed
        return TripTrophies.compute(trip: summary, history: history).filter { trophy in
            if case .interval(let interval) = trophy.kind { return displayed.contains(interval) }
            return true
        }
    }

    /// Records tous trajets confondus, trajet tout juste terminé compris.
    private var recordTimes: [SpeedInterval: TimeInterval] {
        var all: [[SpeedInterval: TimeInterval]] = []
        for trip in trips {
            all.append(trip.summary.bestTimes)
        }
        if let summary = model.summary {
            all.append(summary.bestTimes)
        }
        return RecordBook.best(of: all)
    }

    private var summaryPresented: Binding<Bool> {
        Binding(
            get: { model.state == .finished && model.summary != nil },
            set: { presented in
                if !presented {
                    model.reset()
                }
            })
    }
}

#Preview {
    TripScreen()
        .modelContainer(for: [TripRecord.self, RivalRecord.self], inMemory: true)
}
