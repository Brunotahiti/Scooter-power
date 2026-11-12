import SwiftUI
import ScooterCore
import UIKit

struct TripScreen: View {
    @State private var model = TripViewModel()
    @State private var showMap = false
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var confirmFinish = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                HeaderView(state: model.state, onRecalibrate: { model.recalibrate() })

                if model.locationDenied {
                    locationDeniedBanner
                }
                if model.gpsWeak {
                    banner(icon: "location.slash", text: "Signal GPS faible")
                }

                SpeedometerView(speedKmh: model.speedKmh)

                HStack(spacing: 10) {
                    BigStatCard(icon: "mountain.2", title: "Vitesse maximale", value: model.maxSpeedText, unit: "km/h")
                    BigStatCard(icon: "gauge.with.needle", title: "Vitesse moyenne", value: model.averageSpeedText, unit: "km/h")
                }
                HStack(spacing: 10) {
                    DualStatCard(
                        first: .init(icon: "mappin", title: "Distance", value: model.distanceText),
                        second: .init(icon: "triangle", title: "Altitude", value: model.altitudeText))
                    DualStatCard(
                        first: .init(icon: "stopwatch", title: "Durée de roulage", value: model.movingDurationText),
                        second: .init(icon: nil, title: "Durée totale", value: model.totalDurationText))
                }

                AccelerationCard(
                    value: model.accelerationValue,
                    valueText: model.accelerationText,
                    level: model.accelerationLevel,
                    history: model.accelerationHistory,
                    peakText: model.peakText)

                SprintCard(
                    best50Text: model.sprint50Text,
                    best80Text: model.sprint80Text,
                    isRunning: model.sprintRunning,
                    elapsedText: model.sprintElapsedText)

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
        .sheet(isPresented: $showMap) {
            MapSheet(route: model.route, showsUser: !model.isDemo)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker()
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: summaryPresented) {
            if let summary = model.summary {
                SummaryView(summary: summary, onDone: { model.reset() })
            }
        }
        .confirmationDialog("Terminer le trajet ?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Terminer", role: .destructive) { model.finish() }
            Button("Annuler", role: .cancel) {}
        }
        .alert("Appareil photo indisponible", isPresented: $showCameraUnavailable) {
            Button("OK", role: .cancel) {}
        }
        .preferredColorScheme(.dark)
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
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
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

#Preview {
    TripScreen()
}
