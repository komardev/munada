import Foundation
import UserNotifications

enum NotifPrefs {
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notifEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notifEnabled") }
    }
    static var preAlert: Int {
        get { UserDefaults.standard.integer(forKey: "notifPreAlert") }
        set { UserDefaults.standard.set(newValue, forKey: "notifPreAlert") }
    }
    static let preAlertOptions = [0, 5, 10, 15]
}

final class Notifier {
    static let shared = Notifier()
    private let center = UNUserNotificationCenter.current()

    private let daysAhead = 3

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

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

        let slots = engine.upcomingSlots(now: now, days: daysAhead).filter { $0.kind != .sunrise }

        for slot in slots {
            add(id: "munada.\(slot.kind.rawValue).\(Int(slot.date.timeIntervalSince1970))",
                title: L10n.notifEntered(slot.name),
                body: locationName,
                fireAt: slot.date, cal: cal)

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
