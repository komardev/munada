import Foundation

enum PrayerKind: String, CaseIterable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha
}

enum Lang: String, CaseIterable {
    case id, en, ar

    var displayName: String {
        switch self {
        case .id: return "Indonesia"
        case .en: return "English"
        case .ar: return "العربية"
        }
    }

    var localeID: String {
        switch self {
        case .id: return "id_ID"
        case .en: return "en_US"
        case .ar: return "ar"
        }
    }
}

enum LKey {
    case now
    case detectLocation, searchCity, language, method, madhab, adjust, reset, openAtLogin, quit
    case notifications, notifEnable, preAlert, off, notifDenied, openSettings, useMethod
    case searchTitle, searchPrompt, searchPlaceholder, searchOK, cancel
    case locationTitle, locationDenied, cityNotFound, currentLocation
}

enum L10n {
    private static let key = "lang"

    static var current: Lang {
        get { Lang(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? systemDefault }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    private static var systemDefault: Lang {
        for code in Locale.preferredLanguages {
            let c = code.lowercased()
            if c.hasPrefix("id") || c.hasPrefix("in") { return .id }
            if c.hasPrefix("ar") { return .ar }
            if c.hasPrefix("en") { return .en }
        }
        return .en
    }

    static var locale: Locale { Locale(identifier: current.localeID) }

    static func prayerName(_ kind: PrayerKind) -> String {
        switch current {
        case .id:
            switch kind {
            case .fajr: return "Subuh";   case .sunrise: return "Terbit"
            case .dhuhr: return "Dzuhur"; case .asr: return "Ashar"
            case .maghrib: return "Maghrib"; case .isha: return "Isya"
            }
        case .en:
            switch kind {
            case .fajr: return "Fajr";    case .sunrise: return "Sunrise"
            case .dhuhr: return "Dhuhr";  case .asr: return "Asr"
            case .maghrib: return "Maghrib"; case .isha: return "Isha"
            }
        case .ar:
            switch kind {
            case .fajr: return "الفجر";   case .sunrise: return "الشروق"
            case .dhuhr: return "الظهر";  case .asr: return "العصر"
            case .maghrib: return "المغرب"; case .isha: return "العشاء"
            }
        }
    }

    static func duration(_ minutes: Int) -> String {
        let (h, m): (String, String)
        switch current {
        case .id: (h, m) = ("j", "m")
        case .en: (h, m) = ("h", "m")
        case .ar: (h, m) = ("س", "د")
        }
        if minutes >= 60 { return "\(minutes / 60)\(h) \(minutes % 60)\(m)" }
        return "\(minutes)\(m)"
    }

    static func notifEntered(_ name: String) -> String {
        switch current {
        case .id: return "Waktunya \(name)"
        case .en: return "Time for \(name)"
        case .ar: return "حان وقت \(name)"
        }
    }

    static func notifSoon(_ name: String, _ mins: Int) -> String {
        switch current {
        case .id: return "\(name) \(mins) menit lagi"
        case .en: return "\(name) in \(mins) min"
        case .ar: return "\(name) بعد \(mins) دقيقة"
        }
    }

    static func suggestMethod(_ country: String, _ method: CalcMethod) -> String {
        switch current {
        case .id: return "Lokasi terdeteksi di \(country). Pakai metode \(method.displayName)?"
        case .en: return "Location detected in \(country). Use the \(method.displayName) method?"
        case .ar: return "تم تحديد موقعك في \(country). هل تريد استخدام طريقة \(method.displayName)؟"
        }
    }

    static func tr(_ k: LKey) -> String {
        table[current]?[k] ?? table[.en]?[k] ?? ""
    }

    private static let table: [Lang: [LKey: String]] = [
        .id: [
            .now: "sekarang",
            .detectLocation: "Deteksi Lokasi Otomatis", .searchCity: "Cari Kota…",
            .language: "Bahasa", .method: "Metode Kalkulasi",
            .madhab: "Mazhab (Ashar)", .adjust: "Koreksi Waktu (menit)", .reset: "Reset ke 0",
            .openAtLogin: "Buka saat login", .quit: "Keluar",
            .searchTitle: "Cari Kota", .searchPrompt: "Ketik nama kota (mis. Cilacap, Dubai):",
            .searchPlaceholder: "Nama kota", .searchOK: "Cari", .cancel: "Batal",
            .locationTitle: "Lokasi",
            .locationDenied: "Izin lokasi ditolak. Aktifkan di System Settings › Privacy › Location.",
            .cityNotFound: "Kota tidak ketemu.", .currentLocation: "Lokasi Saat Ini",
            .notifications: "Notifikasi", .notifEnable: "Aktifkan",
            .preAlert: "Ingatkan Sebelum", .off: "Mati",
            .notifDenied: "Izin notifikasi ditolak. Aktifkan di System Settings › Notifications › Munada.",
            .openSettings: "Buka Pengaturan", .useMethod: "Pakai",
        ],
        .en: [
            .now: "now",
            .detectLocation: "Detect Location Automatically", .searchCity: "Search City…",
            .language: "Language", .method: "Calculation Method",
            .madhab: "Madhab (Asr)", .adjust: "Time Adjustment (min)", .reset: "Reset to 0",
            .openAtLogin: "Open at Login", .quit: "Quit",
            .searchTitle: "Search City", .searchPrompt: "Type a city name (e.g. Jakarta, Dubai):",
            .searchPlaceholder: "City name", .searchOK: "Search", .cancel: "Cancel",
            .locationTitle: "Location",
            .locationDenied: "Location permission denied. Enable it in System Settings › Privacy › Location.",
            .cityNotFound: "City not found.", .currentLocation: "Current Location",
            .notifications: "Notifications", .notifEnable: "Enable",
            .preAlert: "Remind Before", .off: "Off",
            .notifDenied: "Notification permission denied. Enable it in System Settings › Notifications › Munada.",
            .openSettings: "Open Settings", .useMethod: "Use",
        ],
        .ar: [
            .now: "الآن",
            .detectLocation: "تحديد الموقع تلقائيًا", .searchCity: "بحث عن مدينة…",
            .language: "اللغة", .method: "طريقة الحساب",
            .madhab: "المذهب (العصر)", .adjust: "تعديل الوقت (دقيقة)", .reset: "إعادة إلى 0",
            .openAtLogin: "الفتح عند تسجيل الدخول", .quit: "خروج",
            .searchTitle: "بحث عن مدينة", .searchPrompt: "اكتب اسم المدينة (مثل جدة، دبي):",
            .searchPlaceholder: "اسم المدينة", .searchOK: "بحث", .cancel: "إلغاء",
            .locationTitle: "الموقع",
            .locationDenied: "تم رفض إذن الموقع. فعّله من إعدادات النظام › الخصوصية › الموقع.",
            .cityNotFound: "المدينة غير موجودة.", .currentLocation: "الموقع الحالي",
            .notifications: "الإشعارات", .notifEnable: "تفعيل",
            .preAlert: "تذكير قبل", .off: "إيقاف",
            .notifDenied: "تم رفض إذن الإشعارات. فعّله من إعدادات النظام › الإشعارات › Munada.",
            .openSettings: "فتح الإعدادات", .useMethod: "استخدام",
        ],
    ]
}
