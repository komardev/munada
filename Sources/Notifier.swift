import Foundation
import UserNotifications

/// Preferensi notifikasi (UserDefaults). Default mati — biar gak prompt izin tanpa diminta.
enum NotifPrefs {
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notifEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notifEnabled") }
    }
    /// Menit pra-pengingat sebelum waktu masuk; 0 = mati.
    static var preAlert: Int {
        get { UserDefaults.standard.integer(forKey: "notifPreAlert") }
        set { UserDefaults.standard.set(newValue, forKey: "notifPreAlert") }
    }
    static let preAlertOptions = [0, 5, 10, 15]
}

/// Jadwalkan notifikasi waktu sholat lewat UserNotifications.
/// Sistem yang menyimpan & memunculkan notif (tetap bunyi walau app ditutup),
/// selama masih ada di pending list → kita jadwalkan beberapa hari ke depan.
final class Notifier {
    static let shared = Notifier()
    private let center = UNUserNotificationCenter.current()

    /// Hari ke depan yang dijadwalkan. 3 hari × 5 sholat × ≤2 (pra+utama) = ≤30, di bawah batas sistem (~64).
    private let daysAhead = 3

    /// Minta izin (memicu prompt sistem pertama kali). completion di main thread.
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Bersihkan & jadwal ulang sesuai prefs + waktu sholat terkini.
    /// Aman dipanggil sering (tiap ganti setting/lokasi/bangun). Murah.
    func refresh(engine: PrayerEngine, locationName: String) {
        center.removeAllPendingNotificationRequests()
        guard NotifPrefs.enabled else { return }
        center.getNotificationSettings { [weak self] settings in
            guard let self = self,
                  settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            else { return }
            DispatchQueue.main.async { self.schedule(engine: engine, locationName: locationName) }
        }
    }

    private func schedule(engine: PrayerEngine, locationName: String) {
        let now = Date()
        let pre = NotifPrefs.preAlert
        let cal = Calendar.current

        // Terbit/Syuruq bukan waktu sholat → tak dinotif.
        let slots = engine.upcomingSlots(now: now, days: daysAhead).filter { $0.kind != .sunrise }

        for slot in slots {
            // Utama: pas waktu masuk.
            add(id: "munada.\(slot.kind.rawValue).\(Int(slot.date.timeIntervalSince1970))",
                title: L10n.notifEntered(slot.name),
                body: locationName,
                fireAt: slot.date, cal: cal)

            // Pra-pengingat (kalau diaktifkan & masih di masa depan).
            guard pre > 0 else { continue }
            let preDate = slot.date.addingTimeInterval(TimeInterval(-pre * 60))
            guard preDate > now else { continue }
            add(id: "munada.\(slot.kind.rawValue).\(Int(slot.date.timeIntervalSince1970)).pre",
                title: L10n.notifSoon(slot.name, pre),
                body: locationName,
                fireAt: preDate, cal: cal)
        }
    }

    private func add(id: String, title: String, body: String, fireAt: Date, cal: Calendar) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
