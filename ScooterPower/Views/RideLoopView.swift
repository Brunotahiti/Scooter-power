import MapKit
import SwiftUI
import ScooterCore

/// « Fais-moi une boucle de 45 min avec des virages » : l'app propose une
/// balade autour de vous, à rouler contre le temps estimé par Plans.
struct RideLoopView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var planner = RideLoopPlanner()
    @State private var minutes = 45
    @State private var index = 0
    @State private var position: MapCameraPosition = .automatic
    private let units = AppSettings.shared.units
    private static let durations = [20, 45, 60, 90]

    private var candidate: RideLoopPlanner.Candidate? {
        planner.candidates.indices.contains(index) ? planner.candidates[index] : planner.candidates.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker(L("Durée"), selection: $minutes) {
                    ForEach(Self.durations, id: \.self) { value in
                        Text(L("\(String(value)) min")).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                map
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(GhostRaceMap.routeYellow.opacity(0.6), lineWidth: 1.5))
                    .padding(.horizontal, 16)

                if let candidate {
                    stats(candidate)
                }
                if planner.failed && planner.candidates.isEmpty {
                    Text(L("Impossible de proposer une balade ici. Vérifiez la localisation et la connexion."))
                        .font(.footnote)
                        .foregroundStyle(Theme.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                buttons
            }
            .padding(.vertical, 12)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("Balade"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Fermer")) { dismiss() }
                }
            }
            .onChange(of: candidate?.id) { _, _ in frame() }
        }
        .preferredColorScheme(.dark)
    }

    private var map: some View {
        Map(position: $position) {
            if let candidate {
                let path: [CLLocationCoordinate2D] = candidate.route.map(\.mapCoordinate)
                MapPolyline(coordinates: path)
                    .stroke(Color.black.opacity(0.6), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: path)
                    .stroke(GhostRaceMap.routeYellow, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                if let start = path.first {
                    Annotation(L("Départ"), coordinate: start) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14, weight: .bold))
                            .padding(6)
                            .background(Color.black.opacity(0.7), in: Circle())
                    }
                }
            }
            UserAnnotation()
        }
        .mapStyle(.hybrid(elevation: .realistic, pointsOfInterest: .excludingAll))
        .overlay {
            if planner.working && planner.candidates.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(L("Recherche de routes sinueuses…")).font(.footnote)
                }
                .padding(16)
                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            } else if planner.candidates.isEmpty && !planner.working {
                Text(L("Choisissez une durée puis « Proposer une balade »."))
                    .font(.footnote)
                    .padding(12)
                    .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func stats(_ candidate: RideLoopPlanner.Candidate) -> some View {
        HStack {
            figure(Formatters.decimal(units.distance(fromMeters: candidate.meters), digits: 1), units.distanceUnit)
            figure(Formatters.duration(candidate.seconds), L("estimé"))
            figure(Self.curvinessLabel(candidate.curviness), L("virages"))
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 20, weight: .heavy).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    static func curvinessLabel(_ degreesPerKm: Double) -> String {
        switch degreesPerKm {
        case ..<40: return L("Tranquille")
        case ..<90: return L("Sinueuse")
        default: return L("Très sinueuse")
        }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button {
                if planner.candidates.count > 1 {
                    index = (index + 1) % planner.candidates.count
                } else {
                    index = 0
                    Task { await planner.generate(minutes: minutes) }
                }
            } label: {
                Label(planner.candidates.isEmpty ? L("Proposer une balade") : L("Autre balade"),
                      systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.bordered)
            .tint(Theme.cyan)
            .disabled(planner.working && planner.candidates.isEmpty)

            Button {
                guard let candidate, let race = RideLoopPlanner.ghost(for: candidate) else { return }
                TripCommands.shared.raceGhost(race, title: L("Balade · temps estimé"))
                dismiss()
            } label: {
                Label(L("Partir"), systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(GhostRaceMap.routeYellow)
            .foregroundStyle(.black)
            .disabled(candidate == nil)
        }
        .padding(.horizontal, 16)
        .onChange(of: minutes) { _, _ in
            index = 0
            Task { await planner.generate(minutes: minutes) }
        }
    }

    private func frame() {
        guard let candidate, let rect = GhostRaceMap.rect(candidate.route) else { return }
        withAnimation(.easeInOut(duration: 0.6)) { position = .rect(rect) }
    }
}
