import Foundation
import CoreLocation

final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    var onResult: ((_ lat: Double, _ lon: Double, _ name: String, _ country: String?) -> Void)?
    var onError: ((String) -> Void)?

    private var silent = false
    private var retries = 0
    private let maxRetries = 3

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func search(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        geocoder.geocodeAddressString(q) { [weak self] placemarks, _ in
            guard let p = placemarks?.first, let loc = p.location else {
                self?.onError?("\(L10n.tr(.cityNotFound)) (\(q))")
                return
            }
            let name = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? q
            self?.onResult?(loc.coordinate.latitude, loc.coordinate.longitude, name, p.isoCountryCode)
        }
    }

    var isAuthorized: Bool {
        let s = manager.authorizationStatus
        return s == .authorized || s == .authorizedAlways
    }

    func detectIfAuthorized() {
        if isAuthorized {
            silent = true
            retries = 0
            manager.requestLocation()
        }
    }

    func detect() {
        silent = false
        retries = 0
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            onError?(L10n.tr(.locationDenied))
        default:
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .restricted, .denied:
            onError?(L10n.tr(.locationDenied))
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        retries = 0
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            let p = placemarks?.first
            let name = p?.locality
                ?? p?.subAdministrativeArea
                ?? p?.administrativeArea
                ?? L10n.tr(.currentLocation)
            self?.onResult?(lat, lon, name, p?.isoCountryCode)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown {
            if retries < maxRetries {
                retries += 1
                manager.requestLocation()
                return
            }
            if silent { return }
        }
        onError?(error.localizedDescription)
    }
}
