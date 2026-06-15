import Foundation

/// Satu kota preset.
struct City {
    let name: String
    let latitude: Double
    let longitude: Double
}

/// Grup kota preset (per wilayah) buat menu rapi.
struct CityGroup {
    let region: String
    let cities: [City]
}

let presetGroups: [CityGroup] = [
    CityGroup(region: "Jawa", cities: [
        City(name: "Jakarta", latitude: -6.2088, longitude: 106.8456),
        City(name: "Bogor", latitude: -6.5950, longitude: 106.8166),
        City(name: "Depok", latitude: -6.4025, longitude: 106.7942),
        City(name: "Tangerang", latitude: -6.1783, longitude: 106.6319),
        City(name: "Bekasi", latitude: -6.2383, longitude: 106.9756),
        City(name: "Bandung", latitude: -6.9175, longitude: 107.6191),
        City(name: "Cirebon", latitude: -6.7320, longitude: 108.5523),
        City(name: "Semarang", latitude: -6.9667, longitude: 110.4167),
        City(name: "Solo", latitude: -7.5755, longitude: 110.8243),
        City(name: "Yogyakarta", latitude: -7.7956, longitude: 110.3695),
        City(name: "Surabaya", latitude: -7.2575, longitude: 112.7521),
        City(name: "Malang", latitude: -7.9666, longitude: 112.6326),
    ]),
    CityGroup(region: "Sumatera", cities: [
        City(name: "Banda Aceh", latitude: 5.5483, longitude: 95.3238),
        City(name: "Medan", latitude: 3.5952, longitude: 98.6722),
        City(name: "Pekanbaru", latitude: 0.5071, longitude: 101.4478),
        City(name: "Padang", latitude: -0.9471, longitude: 100.4172),
        City(name: "Jambi", latitude: -1.6101, longitude: 103.6131),
        City(name: "Palembang", latitude: -2.9761, longitude: 104.7754),
        City(name: "Bandar Lampung", latitude: -5.3971, longitude: 105.2667),
    ]),
    CityGroup(region: "Kalimantan", cities: [
        City(name: "Pontianak", latitude: -0.0263, longitude: 109.3425),
        City(name: "Banjarmasin", latitude: -3.3186, longitude: 114.5944),
        City(name: "Samarinda", latitude: -0.5022, longitude: 117.1536),
        City(name: "Balikpapan", latitude: -1.2379, longitude: 116.8529),
    ]),
    CityGroup(region: "Sulawesi", cities: [
        City(name: "Makassar", latitude: -5.1477, longitude: 119.4327),
        City(name: "Manado", latitude: 1.4748, longitude: 124.8421),
        City(name: "Palu", latitude: -0.8917, longitude: 119.8707),
        City(name: "Kendari", latitude: -3.9985, longitude: 122.5129),
        City(name: "Gorontalo", latitude: 0.5435, longitude: 123.0568),
    ]),
    CityGroup(region: "Bali & Nusa Tenggara", cities: [
        City(name: "Denpasar", latitude: -8.6500, longitude: 115.2167),
        City(name: "Mataram", latitude: -8.5833, longitude: 116.1167),
        City(name: "Kupang", latitude: -10.1772, longitude: 123.6070),
    ]),
    CityGroup(region: "Indonesia Timur", cities: [
        City(name: "Ambon", latitude: -3.6954, longitude: 128.1814),
        City(name: "Ternate", latitude: 0.7905, longitude: 127.3848),
        City(name: "Jayapura", latitude: -2.5916, longitude: 140.6690),
        City(name: "Sorong", latitude: -0.8762, longitude: 131.2558),
    ]),
    CityGroup(region: "Luar Negeri", cities: [
        City(name: "Mekkah", latitude: 21.4225, longitude: 39.8262),
        City(name: "Madinah", latitude: 24.4709, longitude: 39.6121),
        City(name: "Kuala Lumpur", latitude: 3.1390, longitude: 101.6869),
        City(name: "Singapura", latitude: 1.3521, longitude: 103.8198),
        City(name: "Istanbul", latitude: 41.0082, longitude: 28.9784),
        City(name: "Kairo", latitude: 30.0444, longitude: 31.2357),
    ]),
]

/// Simpan & baca lokasi terpilih di UserDefaults. Default: Jakarta.
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
