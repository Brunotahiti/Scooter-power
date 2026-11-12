import Foundation
import ScooterCore

enum LocationAuthorization {
    case notDetermined, denied, authorized
}

/// Source de points GPS. Les rappels arrivent sur le fil principal.
@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    var onAuthorizationChange: ((LocationAuthorization) -> Void)? { get set }
    var onLocation: ((LocationSample) -> Void)? { get set }
    func requestAuthorization()
    func start()
    func stop()
}

/// Source de mesures de mouvement. Les rappels arrivent sur le fil principal.
@MainActor
protocol MotionProviding: AnyObject {
    var isAvailable: Bool { get }
    var onMotion: ((MotionSample) -> Void)? { get set }
    func start()
    func stop()
}
