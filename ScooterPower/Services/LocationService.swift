import CoreLocation
import ScooterCore

@MainActor
final class LocationService: NSObject, LocationProviding {
    var onAuthorizationChange: ((LocationAuthorization) -> Void)?
    var onLocation: ((LocationSample) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
    }

    var authorization: LocationAuthorization {
        Self.map(manager.authorizationStatus)
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        // Le mode d'arrière-plan « location » est déclaré dans Config/Info.plist.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
    }

    nonisolated private static func map(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorized
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    // CoreLocation appelle le délégué sur le fil où le gestionnaire a été créé : le fil principal.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = Self.map(manager.authorizationStatus)
        MainActor.assumeIsolated {
            onAuthorizationChange?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map { location in
            LocationSample(
                timestamp: location.timestamp.timeIntervalSinceReferenceDate,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                speed: location.speed,
                altitude: location.altitude,
                horizontalAccuracy: location.horizontalAccuracy)
        }
        MainActor.assumeIsolated {
            for sample in samples {
                onLocation?(sample)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Une erreur ponctuelle (pas de signal) n'arrête pas les mises à jour :
        // l'écran affiche « Signal GPS faible » faute de point récent.
    }
}
