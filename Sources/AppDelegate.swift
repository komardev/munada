import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let store = LocationStore()
    private let locationManager = LocationManager()

    /// Engine selalu ikut lokasi tersimpan.
    private var engine: PrayerEngine {
        PrayerEngine(latitude: store.latitude, longitude: store.longitude)
    }

    /// Formatter ikut bahasa aktif (dibuat ulang tiap dipakai — murah utk menu).
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
            button.image = kaabaIcon()         // Ka'bah simpel, template monochrome
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
        }
        // Menu di-build LAZY: cuma pas mau dibuka (lewat menuNeedsUpdate), bukan tiap menit.
        let menu = NSMenu()
        menu.autoenablesItems = false   // item info tetap warna penuh (gak di-dim)
        menu.delegate = self
        statusItem.menu = menu

        // Lokasi berubah (manual / GPS) → update teks.
        store.onChange = { [weak self] in self?.updateTitle() }
        locationManager.onResult = { [weak self] lat, lon, name in
            self?.store.set(latitude: lat, longitude: lon, name: name)
        }
        locationManager.onError = { [weak self] msg in self?.showError(msg) }

        // Bangun dari sleep → update + auto-refresh lokasi (tanpa prompt) kalau izin sudah ada.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)

        updateTitle()
        scheduleMinuteTimer()
    }

    @objc private func didWake() {
        updateTitle()
        locationManager.detectIfAuthorized()
    }

    /// Menu di-isi cuma saat mau dibuka → gak ada kerja sia-sia tiap menit.
    func menuNeedsUpdate(_ menu: NSMenu) {
        populateMenu(menu)
    }

    // MARK: - Buka saat login

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

    /// Gambar Ka'bah 3D (tutup diamond hollow + badan kubus) jadi NSImage template — monochrome.
    /// Pakai drawingHandler → di-redraw vektor per-resolusi (crisp di Retina, mulus).
    private func kaabaIcon() -> NSImage {
        let dim: CGFloat = 15
        // Region art terpakai: x[2.5,21.5] (lebar 19), y[5,22] (tinggi 17), center (12,13.5).
        let scale = (dim - 1) / 19                         // isi penuh, sisa margin tipis
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
                p.lineJoinStyle = .round                  // sudut membulat → mulus
                return p
            }
            NSColor.black.setFill()

            // Tutup atas: diamond ring (hollow tengah).
            let outer = poly([P(12, 22), P(20.5, 18.5), P(12, 15), P(3.5, 18.5)])
            let inner = poly([P(12, 20), P(16, 18.5), P(12, 17), P(8, 18.5)])
            outer.append(inner.reversed)
            outer.windingRule = .evenOdd
            outer.fill()

            // Badan kubus dgn notch V di atas.
            poly([
                P(3.5, 16), P(12, 13), P(20.5, 16),
                P(20.5, 9), P(12, 5), P(3.5, 9),
            ]).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Timer update tiap awal menit — hemat baterai (CPU jarang bangun).
    private func scheduleMinuteTimer() {
        timer?.invalidate()
        let cal = Calendar.current
        guard let nextMinute = cal.nextDate(after: Date(),
                                            matching: DateComponents(second: 0),
                                            matchingPolicy: .nextTime) else { return }
        let t = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in
            self?.updateTitle()
        }
        t.tolerance = 15   // izinkan OS coalesce wakeup → hemat baterai
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Update teks status bar saja (dipanggil tiap menit + saat ada perubahan). Ringan.
    private func updateTitle() {
        let now = Date()
        guard let next = engine.nextPrayer(now: now) else {
            statusItem.button?.title = " –"
            return
        }
        let mins = max(0, Int(next.date.timeIntervalSince(now) / 60.0))
        let dur = mins == 0 ? L10n.tr(.now) : L10n.duration(mins)
        statusItem.button?.title = " \(next.name) \(dur)"   // leading space = gap icon↔teks
    }

    private enum RowKind { case passed, next, upcoming }

    /// Isi ulang menu — dipanggil cuma saat menu mau dibuka.
    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let now = Date()
        guard let next = engine.nextPrayer(now: now) else { return }
        let tf = formatter("HH:mm")

        // 1. Tanggal Masehi + Hijriah.
        let greg = formatter("EEEE, d MMMM yyyy").string(from: now)
        let hijri = formatter("d MMMM yyyy", hijri: true).string(from: now)
        let hijriSuffix = L10n.current == .ar ? " هـ" : " H"
        menu.addItem(twoLineItem(line1: greg, line2: hijri + hijriSuffix,
                                 line1Size: 13, line1Weight: .semibold, accent: false))
        menu.addItem(.separator())

        // 2. Baris waktu sholat (kolom rata kanan; lewat=dim, berikutnya=accent).
        //    Terbit/sunrise ikut tampil sbg info (bukan sholat → gak pernah jadi "berikutnya").
        for slot in engine.todaySlots(now: now) {
            let kind: RowKind = (slot.kind == next.kind && slot.date > now) ? .next
                : (slot.date <= now ? .passed : .upcoming)
            menu.addItem(prayerRow(name: slot.name, time: tf.string(from: slot.date), kind: kind))
        }
        menu.addItem(.separator())

        // 4. Lokasi.
        menu.addItem(sectionLabel(store.name))
        menu.addItem(actionItem(L10n.tr(.detectLocation), #selector(detectLocation), symbol: "location.fill"))
        menu.addItem(actionItem(L10n.tr(.searchCity), #selector(searchCity), symbol: "magnifyingglass"))
        menu.addItem(.separator())

        // 5. Bahasa.
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
        menu.addItem(.separator())

        // 6. Buka saat login.
        let loginItem = actionItem(L10n.tr(.openAtLogin), #selector(toggleLogin), symbol: "arrow.right.circle")
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())

        // 7. Keluar.
        menu.addItem(actionItem(L10n.tr(.quit), #selector(quit), symbol: "power", key: "q"))
    }

    // MARK: - Pembuat item menu

    /// Item info: pakai custom view → warna penuh + TIDAK kena highlight hover.
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

/// View teks buat item menu non-interaktif: warna penuh, tanpa highlight hover.
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
