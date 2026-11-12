import CoreMotion
import ScooterCore

@MainActor
final class MotionService: MotionProviding {
    var onMotion: ((MotionSample) -> Void)?

    private let manager = CMMotionManager()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let sample = MotionSample(
                timestamp: motion.timestamp,
                gravity: Vector3(motion.gravity.x, motion.gravity.y, motion.gravity.z),
                userAcceleration: Vector3(
                    motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z))
            MainActor.assumeIsolated {
                self?.onMotion?(sample)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
