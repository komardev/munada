import Foundation

/// Jenis waktu sholat — language-agnostic. Nama tampilan via L10n.
enum PrayerKind: CaseIterable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha
}

/// Bahasa yang didukung.
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

/// Kunci string yang butuh terjemahan.
enum LKey {
    case prayerTimes, next, inDuration, atTime, now
    case detectLocation, searchCity, chooseCity, language, openAtLogin, quit
    case searchTitle, searchPrompt, searchPlaceholder, searchOK, cancel
    case locationTitle, locationDenied, cityNotFound
}

/// Lokalisasi sederhana berbasis kode. Bahasa aktif disimpan di UserDefaults.
enum L10n {
    private static let key = "lang"

    static var current: Lang {
        get { Lang(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .id }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    static var locale: Locale { Locale(identifier: current.localeID) }
    static var isRTL: Bool { current == .ar }

    /// Nama tampilan waktu sholat.
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

    /// Durasi menit → string singkat per bahasa ("1j 23m" / "1h 23m" / "1س 23د").
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

    static func tr(_ k: LKey) -> String {
        table[current]?[k] ?? table[.en]?[k] ?? ""
    }

    private static let table: [Lang: [LKey: String]] = [
        .id: [
            .prayerTimes: "Waktu Sholat", .next: "Berikutnya", .inDuration: "dalam",
            .atTime: "pukul", .now: "sekarang",
            .detectLocation: "Deteksi Lokasi Otomatis", .searchCity: "Cari Kota…",
            .chooseCity: "Pilih Kota", .language: "Bahasa",
            .openAtLogin: "Buka saat login", .quit: "Keluar",
            .searchTitle: "Cari Kota", .searchPrompt: "Ketik nama kota (mis. Cilacap, Dubai):",
            .searchPlaceholder: "Nama kota", .searchOK: "Cari", .cancel: "Batal",
            .locationTitle: "Lokasi",
            .locationDenied: "Izin lokasi ditolak. Aktifkan di System Settings › Privacy › Location.",
            .cityNotFound: "Kota tidak ketemu.",
        ],
        .en: [
            .prayerTimes: "Prayer Times", .next: "Next", .inDuration: "in",
            .atTime: "at", .now: "now",
            .detectLocation: "Detect Location Automatically", .searchCity: "Search City…",
            .chooseCity: "Choose City", .language: "Language",
            .openAtLogin: "Open at Login", .quit: "Quit",
            .searchTitle: "Search City", .searchPrompt: "Type a city name (e.g. Jakarta, Dubai):",
            .searchPlaceholder: "City name", .searchOK: "Search", .cancel: "Cancel",
            .locationTitle: "Location",
            .locationDenied: "Location permission denied. Enable it in System Settings › Privacy › Location.",
            .cityNotFound: "City not found.",
        ],
        .ar: [
            .prayerTimes: "أوقات الصلاة", .next: "التالية", .inDuration: "خلال",
            .atTime: "الساعة", .now: "الآن",
            .detectLocation: "تحديد الموقع تلقائيًا", .searchCity: "بحث عن مدينة…",
            .chooseCity: "اختر مدينة", .language: "اللغة",
            .openAtLogin: "الفتح عند تسجيل الدخول", .quit: "خروج",
            .searchTitle: "بحث عن مدينة", .searchPrompt: "اكتب اسم المدينة (مثل جدة، دبي):",
            .searchPlaceholder: "اسم المدينة", .searchOK: "بحث", .cancel: "إلغاء",
            .locationTitle: "الموقع",
            .locationDenied: "تم رفض إذن الموقع. فعّله من إعدادات النظام › الخصوصية › الموقع.",
            .cityNotFound: "المدينة غير موجودة.",
        ],
    ]
}
