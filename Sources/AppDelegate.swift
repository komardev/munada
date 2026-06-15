import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastNotifDay = 0
    private let store = LocationStore()
    private let locationManager = LocationManager()

    private var engine: PrayerEngine {
        PrayerEngine(latitude: store.latitude, longitude: store.longitude)
    }

    private func formatter(_ fmt: String, hijri: Bool = false) -> DateFormatter {
        let f = DateFormatter()
        f.locale = L10n.locale
        if hijri { f.calendar = Calendar(identifier: .islamicUmmAlQura) }
        f.dateFormat = fmt
        return f
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            button.image = kaabaIcon()
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        store.onChange = { [weak self] in self?.updateTitle(); self?.scheduleNotifications() }
        locationManager.onResult = { [weak self] lat, lon, name, country in
            self?.store.set(latitude: lat, longitude: lon, name: name)
            self?.maybeSuggestMethod(country: country)
        }
        locationManager.onError = { [weak self] msg in self?.showError(msg) }

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)

        updateTitle()
        scheduleMinuteTimer()
        scheduleNotifications()
    }

    @objc private func didWake() {
        updateTitle()
        locationManager.detectIfAuthorized()
        scheduleNotifications()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populateMenu(menu)
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func kaabaIcon() -> NSImage {
        let dim: CGFloat = 15
        let scale = (dim - 1) / 19
        let image = NSImage(size: NSSize(width: dim, height: dim), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current else { return false }
            ctx.shouldAntialias = true
            ctx.imageInterpolation = .high

            func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: dim / 2 + (x - 12) * scale, y: dim / 2 + (y - 13.5) * scale)
            }
            func poly(_ pts: [NSPoint]) -> NSBezierPath {
                let p = NSBezierPath()
                p.move(to: pts[0]); for q in pts.dropFirst() { p.line(to: q) }
                p.close()
                p.lineJoinStyle = .round
                return p
            }
            NSColor.black.setFill()

            let outer = poly([P(12, 22), P(20.5, 18.5), P(12, 15), P(3.5, 18.5)])
            let inner = poly([P(12, 20), P(16, 18.5), P(12, 17), P(8, 18.5)])
            outer.append(inner.reversed)
            outer.windingRule = .evenOdd
            outer.fill()

            poly([
                P(3.5, 16), P(12, 13), P(20.5, 16),
                P(20.5, 9), P(12, 5), P(3.5, 9),
            ]).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    private func scheduleMinuteTimer() {
        timer?.invalidate()
        let cal = Calendar.current
        guard let nextMinute = cal.nextDate(after: Date(),
                                            matching: DateComponents(second: 0),
                                            matchingPolicy: .nextTime) else { return }
        let t = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in
            self?.updateTitle()
        }
        t.tolerance = 15
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func updateTitle() {
        let now = Date()
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        if day != lastNotifDay { lastNotifDay = day; scheduleNotifications() }
        guard let next = engine.nextPrayer(now: now) else {
            statusItem.button?.title = " –"
            return
        }
        let mins = max(0, Int(next.date.timeIntervalSince(now) / 60.0))
        let dur = mins == 0 ? L10n.tr(.now) : L10n.duration(mins)
        statusItem.button?.title = " \(next.name) \(dur)"
    }

    private enum RowKind { case passed, next, upcoming }

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let now = Date()
        guard let next = engine.nextPrayer(now: now) else { return }
        let tf = formatter("HH:mm")

        let greg = formatter("EEEE, d MMMM yyyy").string(from: now)
        let hijri = formatter("d MMMM yyyy", hijri: true).string(from: now)
        let hijriSuffix = L10n.current == .ar ? " هـ" : " H"
        menu.addItem(twoLineItem(line1: greg, line2: hijri + hijriSuffix,
                                 line1Size: 13, line1Weight: .semibold, accent: false))
        menu.addItem(.separator())

        for slot in engine.todaySlots(now: now) {
            let kind: RowKind = (slot.kind == next.kind && slot.date > now) ? .next
                : (slot.date <= now ? .passed : .upcoming)
            menu.addItem(prayerRow(name: slot.name, time: tf.string(from: slot.date), kind: kind))
        }
        menu.addItem(.separator())

        menu.addItem(sectionLabel(store.name))
        menu.addItem(actionItem(L10n.tr(.detectLocation), #selector(detectLocation), symbol: "location.fill"))
        menu.addItem(actionItem(L10n.tr(.searchCity), #selector(searchCity), symbol: "magnifyingglass"))
        menu.addItem(.separator())

        let langItem = actionItem(L10n.tr(.language), nil, symbol: "globe")
        let langMenu = NSMenu()
        for lang in Lang.allCases {
            let it = NSMenuItem(title: lang.displayName, action: #selector(selectLang(_:)), keyEquivalent: "")
            it.representedObject = lang.rawValue
            if lang == L10n.current { it.state = .on }
            langMenu.addItem(it)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        let methodItem = actionItem(L10n.tr(.method), nil, symbol: "ruler")
        let methodMenu = NSMenu()
        for m in CalcMethod.allCases {
            let it = NSMenuItem(title: m.displayName, action: #selector(selectMethod(_:)), keyEquivalent: "")
            it.representedObject = m.rawValue
            if m == CalcMethod.current { it.state = .on }
            methodMenu.addItem(it)
        }
        methodItem.submenu = methodMenu
        menu.addItem(methodItem)

        let madhabItem = actionItem(L10n.tr(.madhab), nil, symbol: "sun.max")
        let madhabMenu = NSMenu()
        for mz in MadhabPref.allCases {
            let it = NSMenuItem(title: mz.displayName, action: #selector(selectMadhab(_:)), keyEquivalent: "")
            it.representedObject = mz.rawValue
            if mz == MadhabPref.current { it.state = .on }
            madhabMenu.addItem(it)
        }
        madhabItem.submenu = madhabMenu
        menu.addItem(madhabItem)

        let adjItem = actionItem(L10n.tr(.adjust), nil, symbol: "plusminus")
        let adjMenu = NSMenu()
        for kind in PrayerKind.allCases {
            let cur = Offsets.minutes(kind)
            let suffix = cur == 0 ? "" : String(format: "  (%+d)", cur)
            let row = NSMenuItem(title: L10n.prayerName(kind) + suffix, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for v in Offsets.range {
                let label = v == 0 ? "0" : String(format: "%+d", v)
                let it = NSMenuItem(title: label, action: #selector(selectOffset(_:)), keyEquivalent: "")
                it.representedObject = ["kind": kind.rawValue, "min": v] as [String: Any]
                if v == cur { it.state = .on }
                sub.addItem(it)
            }
            row.submenu = sub
            adjMenu.addItem(row)
        }
        adjMenu.addItem(.separator())
        adjMenu.addItem(NSMenuItem(title: L10n.tr(.reset), action: #selector(resetOffsets), keyEquivalent: ""))
        adjItem.submenu = adjMenu
        menu.addItem(adjItem)
        menu.addItem(.separator())

        let notifItem = actionItem(L10n.tr(.notifications), nil, symbol: "bell")
        let notifMenu = NSMenu()
        let onItem = NSMenuItem(title: L10n.tr(.notifEnable), action: #selector(toggleNotif), keyEquivalent: "")
        onItem.state = NotifPrefs.enabled ? .on : .off
        notifMenu.addItem(onItem)
        let preItem = NSMenuItem(title: L10n.tr(.preAlert), action: nil, keyEquivalent: "")
        let preMenu = NSMenu()
        for v in NotifPrefs.preAlertOptions {
            let it = NSMenuItem(title: v == 0 ? L10n.tr(.off) : L10n.duration(v),
                                action: #selector(selectPreAlert(_:)), keyEquivalent: "")
            it.representedObject = v
            if v == NotifPrefs.preAlert { it.state = .on }
            preMenu.addItem(it)
        }
        preItem.submenu = preMenu
        notifMenu.addItem(preItem)
        notifItem.submenu = notifMenu
        menu.addItem(notifItem)
        menu.addItem(.separator())

        let loginItem = actionItem(L10n.tr(.openAtLogin), #selector(toggleLogin), symbol: "arrow.right.circle")
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())

        menu.addItem(actionItem(L10n.tr(.quit), #selector(quit), symbol: "power", key: "q"))
    }

    private func infoItem(_ attr: NSAttributedString) -> NSMenuItem {
        let i = NSMenuItem()
        i.view = MenuRowView(attr)
        return i
    }

    private func twoLineItem(line1: String, line2: String,
                             line1Size: CGFloat, line1Weight: NSFont.Weight,
                             accent: Bool) -> NSMenuItem {
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: line1 + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: line1Size, weight: line1Weight),
            .foregroundColor: accent ? NSColor.controlAccentColor : NSColor.labelColor,
        ]))
        s.append(NSAttributedString(string: line2, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return infoItem(s)
    }

    private func sectionLabel(_ text: String) -> NSMenuItem {
        infoItem(NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
    }

    private func prayerRow(name: String, time: String, kind: RowKind) -> NSMenuItem {
        let para = NSMutableParagraphStyle()
        para.tabStops = [NSTextTab(textAlignment: .right, location: 160)]
        let font: NSFont
        let color: NSColor
        switch kind {
        case .next:     font = .systemFont(ofSize: 13, weight: .bold); color = .labelColor
        case .passed:   font = .systemFont(ofSize: 13); color = .tertiaryLabelColor
        case .upcoming: font = .systemFont(ofSize: 13); color = .secondaryLabelColor
        }
        let s = NSAttributedString(string: "\(name)\t\(time)", attributes: [
            .paragraphStyle: para, .font: font, .foregroundColor: color,
        ])
        return infoItem(s)
    }

    private func actionItem(_ title: String, _ action: Selector?, symbol: String, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return i
    }

    @objc private func selectLang(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let lang = Lang(rawValue: raw) else { return }
        L10n.current = lang
        updateTitle()
        scheduleNotifications()
    }

    @objc private func selectMethod(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let m = CalcMethod(rawValue: raw) else { return }
        CalcMethod.current = m
        updateTitle()
        scheduleNotifications()
    }

    @objc private func selectMadhab(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mz = MadhabPref(rawValue: raw) else { return }
        MadhabPref.current = mz
        updateTitle()
        scheduleNotifications()
    }

    @objc private func selectOffset(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? [String: Any],
              let raw = d["kind"] as? String, let kind = PrayerKind(rawValue: raw),
              let min = d["min"] as? Int else { return }
        Offsets.set(min, kind)
        updateTitle()
        scheduleNotifications()
    }

    @objc private func resetOffsets() {
        for kind in PrayerKind.allCases { Offsets.set(0, kind) }
        updateTitle()
        scheduleNotifications()
    }

    private func scheduleNotifications() {
        Notifier.shared.refresh(engine: engine, locationName: store.name)
    }

    @objc private func toggleNotif() {
        if NotifPrefs.enabled {
            NotifPrefs.enabled = false
            scheduleNotifications()
        } else {
            Notifier.shared.requestAuthorization { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    NotifPrefs.enabled = true
                    self.scheduleNotifications()
                } else {
                    self.showNotifDenied()
                }
            }
        }
    }

    @objc private func selectPreAlert(_ sender: NSMenuItem) {
        guard let v = sender.representedObject as? Int else { return }
        NotifPrefs.preAlert = v
        scheduleNotifications()
    }

    private func maybeSuggestMethod(country: String?) {
        guard let code = country,
              let rec = CalcMethod.recommended(forCountryCode: code),
              rec != CalcMethod.current else { return }
        let key = "lastSuggestCountry"
        guard UserDefaults.standard.string(forKey: key) != code else { return }
        UserDefaults.standard.set(code, forKey: key)

        let countryName = Locale(identifier: L10n.current.localeID).localizedString(forRegionCode: code) ?? code
        let alert = NSAlert()
        alert.messageText = L10n.tr(.method)
        alert.informativeText = L10n.suggestMethod(countryName, rec)
        alert.addButton(withTitle: L10n.tr(.useMethod))
        alert.addButton(withTitle: L10n.tr(.cancel))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            CalcMethod.current = rec
            updateTitle()
            scheduleNotifications()
        }
    }

    @objc private func detectLocation() {
        locationManager.detect()
    }

    @objc private func searchCity() {
        let alert = NSAlert()
        alert.messageText = L10n.tr(.searchTitle)
        alert.informativeText = L10n.tr(.searchPrompt)
        alert.addButton(withTitle: L10n.tr(.searchOK))
        alert.addButton(withTitle: L10n.tr(.cancel))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = L10n.tr(.searchPlaceholder)
        alert.accessoryView = field
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            locationManager.search(field.stringValue)
        }
    }

    private func showNotifDenied() {
        let alert = NSAlert()
        alert.messageText = L10n.tr(.notifications)
        alert.informativeText = L10n.tr(.notifDenied)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.tr(.openSettings))
        alert.addButton(withTitle: L10n.tr(.cancel))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.tr(.locationTitle)
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

final class MenuRowView: NSView {
    private static let leftInset: CGFloat = 14
    private static let rightInset: CGFloat = 14
    private static let vPad: CGFloat = 3

    private let attr: NSAttributedString

    init(_ attr: NSAttributedString) {
        self.attr = attr
        let s = attr.size()
        let frame = NSRect(x: 0, y: 0,
                           width: Self.leftInset + ceil(s.width) + Self.rightInset,
                           height: ceil(s.height) + Self.vPad * 2)
        super.init(frame: frame)
        autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let s = attr.size()
        let y = (bounds.height - s.height) / 2
        attr.draw(at: NSPoint(x: Self.leftInset, y: y))
    }
}
