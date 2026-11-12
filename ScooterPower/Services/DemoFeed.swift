import Foundation
import ScooterCore

/// Remplace les deux capteurs par le trajet synthétique de `DemoTrip`,
/// quand les capteurs de mouvement sont absents (simulateur).
@MainActor
final class DemoFeed: LocationProviding, MotionProviding {
    var onAuthorizationChange: ((LocationAuthorization) -> Void)?
    var onLocation: ((LocationSample) -> Void)?
    var onMotion: ((MotionSample) -> Void)?

    let authorization = LocationAuthorization.authorized
    let isAvailable = true

    private let trip = DemoTrip()
    private var timer: Timer?
    private var startDate = Date()
    private var tick = 0
    /// Les deux protocoles appellent chacun `start()` et `stop()`.
    private var clients = 0

    func requestAuthorization() {}

    func start() {
        clients += 1
        guard timer == nil else { return }
        startDate = Date()
        tick = 0
        let timer = Timer(timeInterval: 1.0 / 50.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.emit()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        clients = max(0, clients - 1)
        guard clients == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func emit() {
        let elapsed = Date().timeIntervalSince(startDate)
        onMotion?(trip.motion(at: elapsed))

        if tick % 50 == 0 {
            // Même horloge que LocationService, pour que les durées du trajet restent cohérentes.
            var location = trip.location(at: elapsed)
            location.timestamp = startDate.timeIntervalSinceReferenceDate + elapsed
            onLocation?(location)
        }
        tick += 1
    }
}
