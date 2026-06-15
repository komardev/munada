import Foundation
import Adhan

struct PrayerSlot {
    let kind: PrayerKind
    let date: Date
    var name: String { L10n.prayerName(kind) }
}

enum CalcMethod: String, CaseIterable {
    case kemenag, mwl, ummAlQura, egyptian, karachi, isna
    case dubai, kuwait, qatar, singapore, turkey, tehran, moonsighting

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

    static func recommended(forCountryCode code: String?) -> CalcMethod? {
        guard let c = code?.uppercased() else { return nil }
        switch c {
        case "ID":                               return .kemenag
        case "MY", "SG", "BN":                   return .singapore
        case "SA", "YE":                         return .ummAlQura
        case "AE":                               return .dubai
        case "KW":                               return .kuwait
        case "QA", "BH":                         return .qatar
        case "EG", "SY", "LB", "LY", "SD", "JO": return .egyptian
        case "PK", "IN", "BD", "AF", "LK":       return .karachi
        case "TR":                               return .turkey
        case "IR":                               return .tehran
        case "US", "CA", "MX":                   return .isna
        case "GB", "IE":                         return .moonsighting
        default:                                 return .mwl
        }
    }
}

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

enum Offsets {
    static let range = -5...5

    static func minutes(_ kind: PrayerKind) -> Int {
        UserDefaults.standard.integer(forKey: "offset_\(kind.rawValue)")
    }
    static func set(_ m: Int, _ kind: PrayerKind) {
        UserDefaults.standard.set(m, forKey: "offset_\(kind.rawValue)")
    }
}

struct PrayerEngine {
    var latitude: Double = -6.2088
    var longitude: Double = 106.8456

    private let calendar = Calendar(identifier: .gregorian)

    private func params() -> CalculationParameters {
        var p = CalcMethod.current.params
        p.madhab = MadhabPref.current.adhan
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

    func todaySlots(now: Date = Date()) -> [PrayerSlot] {
        slots(for: now)
    }

    func upcomingSlots(now: Date = Date(), days: Int) -> [PrayerSlot] {
        var out: [PrayerSlot] = []
        for d in 0..<max(1, days) {
            guard let day = calendar.date(byAdding: .day, value: d, to: now) else { continue }
            out += slots(for: day)
        }
        return out.filter { $0.date > now }
    }

    func nextPrayer(now: Date = Date()) -> PrayerSlot? {
        let today = slots(for: now).filter { $0.kind != .sunrise }
        if let next = today.first(where: { $0.date > now }) {
            return next
        }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        return slots(for: tomorrow).first { $0.kind == .fajr }
    }
}
