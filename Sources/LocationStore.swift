import Foundation

final class LocationStore {
    private let d = UserDefaults.standard
    private enum Key { static let lat = "lat", lon = "lon", name = "name" }

    var onChange: (() -> Void)?

    var latitude: Double {
        d.object(forKey: Key.lat) == nil ? -6.2088 : d.double(forKey: Key.lat)
    }
    var longitude: Double {
        d.object(forKey: Key.lon) == nil ? 106.8456 : d.double(forKey: Key.lon)
    }
    var name: String {
        d.string(forKey: Key.name) ?? "Jakarta"
    }

    func set(latitude: Double, longitude: Double, name: String) {
        d.set(latitude, forKey: Key.lat)
        d.set(longitude, forKey: Key.lon)
        d.set(name, forKey: Key.name)
        onChange?()
    }
}
