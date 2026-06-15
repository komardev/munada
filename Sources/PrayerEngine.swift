import Foundation
import Adhan

/// Satu waktu sholat: jenis + jam. Nama tampilan via L10n.
struct PrayerSlot {
    let kind: PrayerKind
    let date: Date
    var name: String { L10n.prayerName(kind) }
}

/// Hitung waktu sholat offline pakai Adhan. Default: Jakarta + metode Kemenag (Fajr 20°, Isha 18°).
struct PrayerEngine {
    var latitude: Double = -6.2088   // Jakarta
    var longitude: Double = 106.8456

    private let calendar = Calendar(identifier: .gregorian)

    /// Parameter kalkulasi gaya Kemenag Indonesia.
    private func params() -> CalculationParameters {
        var p = CalculationMethod.other.params
        p.fajrAngle = 20.0
        p.ishaAngle = 18.0
        p.madhab = .shafi
        return p
    }

    private func prayerTimes(for day: Date) -> PrayerTimes? {
        let coords = Coordinates(latitude: latitude, longitude: longitude)
        let comps = calendar.dateComponents([.year, .month, .day], from: day)
        return PrayerTimes(coordinates: coords, date: comps, calculationParameters: params())
    }

    private func slots(for day: Date) -> [PrayerSlot] {
        guard let t = prayerTimes(for: day) else { return [] }
        return [
            PrayerSlot(kind: .fajr, date: t.fajr),
            PrayerSlot(kind: .sunrise, date: t.sunrise),
            PrayerSlot(kind: .dhuhr, date: t.dhuhr),
            PrayerSlot(kind: .asr, date: t.asr),
            PrayerSlot(kind: .maghrib, date: t.maghrib),
            PrayerSlot(kind: .isha, date: t.isha),
        ]
    }

    /// Semua waktu sholat hari ini (buat dropdown).
    func todaySlots(now: Date = Date()) -> [PrayerSlot] {
        slots(for: now)
    }

    /// Sholat berikutnya. Kalau Isya sudah lewat, ambil Subuh besok.
    func nextPrayer(now: Date = Date()) -> PrayerSlot? {
        let today = slots(for: now).filter { $0.kind != .sunrise }
        if let next = today.first(where: { $0.date > now }) {
            return next
        }
        // Semua lewat → Subuh besok.
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        return slots(for: tomorrow).first { $0.kind == .fajr }
    }
}
