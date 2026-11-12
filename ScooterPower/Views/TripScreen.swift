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
    private let settings = AppSettings.shared
    @Environment(\.modelContext) private var modelContext
    /// Tous les trajets enregistrés : la source des records.
    @Query private var history: [TripRecord]
    @Environment(\.openURL) private var openURL
    /// Compacte quand l'iPhone est en paysage.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        layout
            .overlay(alignment: .top) {
                recordBanner
            }
            .animation(.spring(duration: 0.4), value: model.recordBanner)
            .onAppear {
                loadRecords()
            }
            .onChange(of: history.count) { _, _ in
                loadRecords()
            }
            .onChange(of: settings.units) { _, _ in
                model.settingsChanged()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showRecords) {
                RecordsSheet(trips: history)
            }
            .modifier(TripPresentations(
                model: model,
                showMap: $showMap,
                showCamera: $showCamera,
                showCameraUnavailable: $showCameraUnavailable,
                confirmFinish: $confirmFinish,
                showHistory: $showHistory))
            .onChange(of: verticalSizeClass) { _, _ in
                // Le téléphone a tourné sur son support : la position verticale a changé.
                model.recalibrate()
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
                onOpenSettings: { openSettings() })
        } else {
            portrait
        }
    }

    private var portrait: some View {
        ScrollView {
            VStack(spacing: 6) {
                HeaderView(
                    state: model.state,
                    onHistory: { showHistory = true },
                    onSettings: { showSettings = true },
                    onRecalibrate: { model.recalibrate() })

                if model.locationDenied {
                    locationDeniedBanner
                }
                if model.gpsWeak {
                    banner(icon: "location.slash", text: L("Signal GPS faible"))
                }

                SpeedometerView(
                    speed: model.speedValue,
                    unit: model.speedUnit,
                    maxSpeed: model.speedometerMax,
                    labelStep: model.speedometerStep,
                    isAlert: model.speedAlertActive,
                    scale: 0.87)

                speedCards
                tripCards

                AccelerationCard(
                    value: model.accelerationValue,
                    valueText: model.accelerationText,
                    level: model.accelerationLevel,
                    history: model.accelerationHistory,
                    peakText: model.peakText)

                SprintCard(
                    times: model.sprintTexts,
                    records: model.recordTexts,
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

                LeanCard(degrees: model.leanDegrees, text: model.leanText, side: model.leanSide)

                if model.isDemo {
                    Text("Données d'illustration")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 2)
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(
                state: model.state,
                onMap: { showMap = true },
                onTogglePause: { model.togglePause() },
                onMain: { mainAction() },
                onPhoto: { takePhoto() })
        }
    }

    private var speedCards: some View {
        HStack(spacing: 10) {
            BigStatCard(icon: "mountain.2", title: L("Vitesse maximale"), value: model.maxSpeedText, unit: model.speedUnit)
            BigStatCard(
                icon: "gauge.with.needle", title: L("Vitesse moyenne"),
                value: model.averageSpeedText, unit: model.speedUnit)
        }
    }

    private var tripCards: some View {
        HStack(spacing: 10) {
            DualStatCard(
                first: .init(icon: "mappin", title: L("Distance"), value: model.distanceText),
                second: .init(icon: "triangle", title: L("Altitude"), value: model.altitudeText))
            DualStatCard(
                first: .init(icon: "stopwatch", title: L("Durée de roulage"), value: model.movingDurationText),
                second: .init(icon: nil, title: L("Durée totale"), value: model.totalDurationText))
        }
    }

    /// Enregistre le trajet qui vient de se terminer dans l'historique.
    private func saveTrip() {
        guard let summary = model.summary, let startDate = model.startDate else { return }
        let record = TripRecord(startDate: startDate, summary: summary, route: model.route)
        modelContext.insert(record)
        // Écriture immédiate : sans elle, quitter l'app juste après peut perdre le trajet.
        try? modelContext.save()
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
            Label("Scooter Power a besoin de votre position pour mesurer le trajet.", systemImage: "location.slash")
                .font(.system(size: 14))
            Button("Ouvrir Réglages") {
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

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showMap) {
                MapSheet(route: model.route, showsUser: !model.isDemo)
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
                        date: model.startDate,
                        onDone: { model.reset() })
                }
            }
            .confirmationDialog("Terminer le trajet ?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Terminer", role: .destructive) { model.finish() }
                Button("Annuler", role: .cancel) {}
            }
            .alert("Appareil photo indisponible", isPresented: $showCameraUnavailable) {
                Button("OK", role: .cancel) {}
            }
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
        .modelContainer(for: TripRecord.self, inMemory: true)
}
