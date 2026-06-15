import Foundation
import CoreLocation

/// Deteksi lokasi GPS + reverse-geocode jadi nama kota.
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    var onResult: ((_ lat: Double, _ lon: Double, _ name: String, _ country: String?) -> Void)?
    var onError: ((String) -> Void)?

    /// Mode silent: auto-refresh (bangun sleep / startup) — udah ada lokasi tersimpan,
    /// jadi error sementara gak usah diganggu ke user.
    private var silent = false
    /// Retry counter buat kCLErrorLocationUnknown (error 0) — CoreLocation cold pas startup.
    private var retries = 0
    private let maxRetries = 3

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Cari kota by nama (forward geocode). Hasil lewat onResult / onError.
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

    /// Re-detect tanpa prompt — cuma kalau izin sudah ada (buat auto-refresh pas bangun sleep).
    func detectIfAuthorized() {
        if isAuthorized {
            silent = true
            retries = 0
            manager.requestLocation()
        }
    }

    /// Mulai deteksi. Minta izin dulu kalau belum.
    func detect() {
        silent = false
        retries = 0
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()   // hasil ditunggu di didChangeAuthorization
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
        // kCLErrorLocationUnknown (error 0): CoreLocation belum siap (cold start /
        // bangun sleep). Sementara, bukan fatal — retry, jangan ganggu user.
        if (error as? CLError)?.code == .locationUnknown {
            if retries < maxRetries {
                retries += 1
                manager.requestLocation()
                return
            }
            // Habis retry & lagi auto-refresh: udah ada lokasi tersimpan, diem aja.
            if silent { return }
        }
        onError?(error.localizedDescription)
    }
}
