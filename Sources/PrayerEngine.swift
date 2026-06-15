import Foundation
import Adhan

/// Satu waktu sholat: jenis + jam. Nama tampilan via L10n.
struct PrayerSlot {
    let kind: PrayerKind
    let date: Date
    var name: String { L10n.prayerName(kind) }
}

/// Metode kalkulasi waktu sholat. Beda wilayah pakai sudut Fajr/Isha beda.
/// Tersimpan di UserDefaults; default Kemenag (Indonesia).
enum CalcMethod: String, CaseIterable {
    case kemenag, mwl, ummAlQura, egyptian, karachi, isna
    case dubai, kuwait, qatar, singapore, turkey, tehran, moonsighting

    /// Nama tampilan (nama lembaga = nama diri, tak diterjemah; hint wilayah dlm kurung).
    var displayName: String {
        switch self {
        case .kemenag:     return "Kemenag (Indonesia)"
        case .mwl:         return "Muslim World League"
        case .ummAlQura:   return "Umm al-Qura (Saudi)"
        case .egyptian:    return "Egyptian"
        case .karachi:     return "Karachi"
        case .isna:        return "ISNA (North America)"
        case .dubai:       return "Dubai"
        case .kuwait:      return "Kuwait"
        case .qatar:       return "Qatar"
        case .singapore:   return "Singapore"
        case .turkey:      return "Turkey"
        case .tehran:      return "Tehran"
        case .moonsighting: return "Moonsighting Committee"
        }
    }

    /// Parameter Adhan per metode. Madhab & koreksi-manual diset terpisah di PrayerEngine.
    /// Kemenag: Fajr 20° / Isha 18° + ihtiyati (margin keamanan) ala jadwal resmi Indonesia —
    /// +2 menit utk sholat, −2 utk Terbit/Syuruq. Ditaruh di `adjustments` (preset lain pakai
    /// `methodAdjustments` internal, jadi tak bentrok dgn koreksi manual yg juga ke `adjustments`).
    var params: CalculationParameters {
        var p: CalculationParameters
        switch self {
        case .kemenag:
            p = CalculationMethod.other.params
            p.fajrAngle = 20.0
            p.ishaAngle = 18.0
            p.adjustments = PrayerAdjustments(fajr: 2, sunrise: -2, dhuhr: 2, asr: 2, maghrib: 2, isha: 2)
        case .mwl:         p = CalculationMethod.muslimWorldLeague.params
        case .ummAlQura:   p = CalculationMethod.ummAlQura.params
        case .egyptian:    p = CalculationMethod.egyptian.params
        case .karachi:     p = CalculationMethod.karachi.params
        case .isna:        p = CalculationMethod.northAmerica.params
        case .dubai:       p = CalculationMethod.dubai.params
        case .kuwait:      p = CalculationMethod.kuwait.params
        case .qatar:       p = CalculationMethod.qatar.params
        case .singapore:   p = CalculationMethod.singapore.params
        case .turkey:      p = CalculationMethod.turkey.params
        case .tehran:      p = CalculationMethod.tehran.params
        case .moonsighting: p = CalculationMethod.moonsightingCommittee.params
        }
        return p
    }

    static var current: CalcMethod {
        get { CalcMethod(rawValue: UserDefaults.standard.string(forKey: "calcMethod") ?? "") ?? .kemenag }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "calcMethod") }
    }
}

/// Mazhab penentu cara hitung Ashar. Shafi (panjang bayangan 1×) juga dipakai Maliki/Hanbali/Jafari;
/// Hanafi (bayangan 2×) → Ashar lebih lambat. Default Shafi (mayoritas Indonesia).
enum MadhabPref: String, CaseIterable {
    case shafi, hanafi

    var displayName: String {
        switch self {
        case .shafi:  return "Syafi'i / Maliki / Hanbali"
        case .hanafi: return "Hanafi"
        }
    }

    var adhan: Madhab { self == .hanafi ? .hanafi : .shafi }

    static var current: MadhabPref {
        get { MadhabPref(rawValue: UserDefaults.standard.string(forKey: "madhab") ?? "") ?? .shafi }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "madhab") }
    }
}

/// Koreksi manual per-waktu (menit), tersimpan di UserDefaults. Buat nyamain ke jadwal lokal.
/// Ditambahkan DI ATAS ihtiyati metode — jadi Kemenag +2 lalu +koreksi user.
enum Offsets {
    static let range = -5...5   // batas wajar; di luar ini bukan koreksi tapi salah metode

    static func minutes(_ kind: PrayerKind) -> Int {
        UserDefaults.standard.integer(forKey: "offset_\(kind.rawValue)")
    }
    static func set(_ m: Int, _ kind: PrayerKind) {
        UserDefaults.standard.set(m, forKey: "offset_\(kind.rawValue)")
    }
}

/// Hitung waktu sholat offline pakai Adhan. Default: Jakarta + metode aktif (CalcMethod.current).
struct PrayerEngine {
    var latitude: Double = -6.2088   // Jakarta
    var longitude: Double = 106.8456

    private let calendar = Calendar(identifier: .gregorian)

    /// Parameter kalkulasi: metode aktif + mazhab + koreksi manual user.
    /// highLatitudeRule sengaja dibiarkan nil → Adhan otomatis pakai .recommended(for: coords)
    /// (lihat CalculationParameters.swift:70), aman utk lintang tinggi.
    private func params() -> CalculationParameters {
        var p = CalcMethod.current.params
        p.madhab = MadhabPref.current.adhan
        // Koreksi user DITAMBAHKAN ke ihtiyati metode (bukan menimpa).
        let base = p.adjustments
        p.adjustments = PrayerAdjustments(
            fajr:    base.fajr    + Offsets.minutes(.fajr),
            sunrise: base.sunrise + Offsets.minutes(.sunrise),
            dhuhr:   base.dhuhr   + Offsets.minutes(.dhuhr),
            asr:     base.asr     + Offsets.minutes(.asr),
            maghrib: base.maghrib + Offsets.minutes(.maghrib),
            isha:    base.isha    + Offsets.minutes(.isha))
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

    /// Slot beberapa hari ke depan (buat jadwal notifikasi), hanya yang belum lewat.
    func upcomingSlots(now: Date = Date(), days: Int) -> [PrayerSlot] {
        var out: [PrayerSlot] = []
        for d in 0..<max(1, days) {
            guard let day = calendar.date(byAdding: .day, value: d, to: now) else { continue }
            out += slots(for: day)
        }
        return out.filter { $0.date > now }
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
