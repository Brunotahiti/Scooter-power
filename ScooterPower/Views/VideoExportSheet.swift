import SwiftUI
import ScooterCore

/// Fabrication de la vidéo du trajet, puis partage (Instagram, TikTok, WhatsApp…).
struct VideoExportSheet: View {
    let replay: TripReplay
    let title: String

    @Environment(\.dismiss) private var dismiss
    @AppStorage(TripMapStyle.storageKey) private var satellite = false
    @State private var progress: Double = 0
    @State private var fileURL: URL?
    @State private var failed = false

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .accessibilityLabel(L("Fermer"))
            }
            Image(systemName: "film.stack")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(SpeedometerView.neonRed)
                .shadow(color: SpeedometerView.neonRed, radius: 14)
            Text(L("Vidéo du trajet"))
                .font(.system(size: 28, weight: .black))
                .italic()
            if let fileURL {
                Text(L("Votre vidéo est prête. Partagez-la sur Instagram, TikTok ou WhatsApp."))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                ShareLink(item: fileURL) {
                    Label(L("Partager la vidéo"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 19, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(Color.white)
                        .background(SpeedometerView.neonRed, in: Capsule())
                }
            } else if failed {
                Text(L("La vidéo n'a pas pu être créée. Vérifiez la connexion (la carte est téléchargée) et réessayez."))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.orange)
            } else {
                Text(L("Création de la vidéo…"))
                    .foregroundStyle(Theme.textSecondary)
                ProgressView(value: progress)
                    .tint(SpeedometerView.neonRed)
                Text(verbatim: "\(Int(progress * 100)) %")
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(24)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
        .task { await export() }
    }

    private func export() async {
        let exporter = ReplayVideoExporter(
            replay: replay, title: title, units: AppSettings.shared.units, satellite: satellite)
        do {
            fileURL = try await exporter.export { value in
                Task { @MainActor in progress = value }
            }
        } catch {
            failed = true
        }
    }
}
