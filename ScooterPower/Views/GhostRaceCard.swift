import SwiftUI
import ScooterCore

/// Bandeau de la course contre le ghost : écart en secondes, positions sur le
/// parcours, puis le résultat à l'arrivée.
struct GhostRaceCard: View {
    let model: TripViewModel
    /// Dans la liste des cartes (portrait) plutôt que posé sur le compteur (paysage).
    var inline = false
    private let units = AppSettings.shared.units

    var body: some View {
        if let title = model.ghostTitle {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(verbatim: "👻")
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(headline)
                            .font(.system(size: status?.phase == .finished ? 24 : 15, weight: .black))
                            .italic(status?.phase == .finished)
                            .foregroundStyle(headlineColor)
                        Text(verbatim: detail ?? title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if let gap = gapText {
                        Text(verbatim: gap)
                            .font(.system(size: 26, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(headlineColor)
                    }
                    Button {
                        model.setGhost(nil, title: nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityLabel(L("Arrêter la course"))
                }
                if let status = model.ghostStatus, status.phase != .waitingForStart {
                    progressBar(rider: status.progress, ghost: status.ghostProgress)
                }
            }
            .padding(12)
            .background {
                ZStack {
                    Theme.card
                    LinearGradient(colors: [headlineColor.opacity(0.18), Color.clear], startPoint: .leading, endPoint: .trailing)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(headlineColor.opacity(0.5), lineWidth: 1))
            .frame(maxWidth: inline ? .infinity : 460)
            .padding(.horizontal, inline ? 0 : 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var status: GhostRace.Status? { model.ghostStatus }

    private var headline: String {
        guard model.state == .recording || model.state == .paused else {
            return L("Touchez Démarrer pour affronter le ghost")
        }
        guard let status else { return L("Rejoignez le départ du ghost") }
        switch status.phase {
        case .waitingForStart:
            return L("Rejoignez le départ du ghost")
        case .racing:
            if status.offRoute { return L("Hors parcours") }
            return (status.gapSeconds ?? 0) >= 0 ? L("Devant le ghost") : L("Derrière le ghost")
        case .finished:
            return (status.gapSeconds ?? 0) >= 0 ? "RACE WIN" : "RACE LOST"
        }
    }

    private var detail: String? {
        guard let status else { return nil }
        switch status.phase {
        case .waitingForStart:
            guard let meters = status.distanceToStart else { return nil }
            let value: String = meters < 1000
                ? Formatters.decimal(units == .metric ? meters : meters * 3.28084, digits: 0) + (units == .metric ? " m" : " ft")
                : Formatters.decimal(units.distance(fromMeters: meters), digits: 1) + " " + units.distanceUnit
            return L("Départ à \(value)")
        case .racing:
            guard let meters = status.gapMeters else { return nil }
            let value: String = Formatters.decimal(abs(units == .metric ? meters : meters * 3.28084), digits: 0)
                + (units == .metric ? " m" : " ft")
            return meters >= 0 ? L("\(value) d'avance") : L("\(value) de retard")
        case .finished:
            guard let mine = status.finishTime, let ghost = status.ghostFinishTime else { return nil }
            return L("Vous \(Formatters.duration(mine)) · ghost \(Formatters.duration(ghost))")
        }
    }

    private var gapText: String? {
        guard let gap = status?.gapSeconds, status?.phase != .waitingForStart else { return nil }
        return Formatters.signed(gap, digits: 1) + " s"
    }

    private var headlineColor: Color {
        guard let status, status.phase != .waitingForStart else { return Theme.cyan }
        if status.offRoute { return Theme.orange }
        return (status.gapSeconds ?? 0) >= 0 ? Color(hex: 0x35D07F) : Theme.red
    }

    /// Le parcours, avec le pilote (plein) et le ghost (translucide).
    private func progressBar(rider: Double, ghost: Double) -> some View {
        GeometryReader { geometry in
            let width: Double = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12)).frame(height: 6)
                Capsule().fill(headlineColor.opacity(0.6)).frame(width: max(6, width * rider), height: 6)
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, min(width - 12, width * ghost - 6)))
                Circle()
                    .fill(headlineColor)
                    .frame(width: 14, height: 14)
                    .offset(x: max(0, min(width - 14, width * rider - 7)))
            }
            .frame(height: 14)
        }
        .frame(height: 14)
    }
}
