import AppKit
import CoreGraphics
import ServiceManagement
import WalkCore
import ReminderAudio

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var engine = WalkTimer()
    private var ticker: Timer?
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let summaryItem = NSMenuItem(title: "Waiting for your desk confirmation", action: nil, keyEquivalent: "")
    private var pauseItem: NSMenuItem!
    private var walkItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var stopSoundItem: NSMenuItem!
    private let alarm = ReminderAlarm()
    private let reminder = ReminderWindow()
    private let preferences = SettingsWindow()
    private let defaults = UserDefaults.standard
    private var loginError: String?
    private var sessionInactive = false
    private var systemSleeping = false
    private var lastTick = Date()
    private var isPreview = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep a UI preview isolated from real preferences and login registration.
        isPreview = ProcessInfo.processInfo.arguments.contains("--preview")
            || Bundle.main.object(forInfoDictionaryKey: "TakeAWalkPreview") as? Bool == true
        if !isPreview, let data = defaults.data(forKey: "walkSettings"),
           let stored = try? JSONDecoder().decode(WalkSettings.self, from: data) {
            engine = WalkTimer(settings: WalkSettings(deskMinutes: stored.deskMinutes,
                              walkMinutes: stored.walkMinutes, awayMinutes: stored.awayMinutes,
                              soundEnabled: stored.soundEnabled))
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "Take a Walk")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        menu.delegate = self
        menu.autoenablesItems = false
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)
        menu.addItem(.separator())
        addItem("Show Take a Walk", action: #selector(showReminder))
        walkItem = addItem("Start walk now", action: #selector(startWalk))
        stopSoundItem = addItem("Stop ringing", action: #selector(stopRinging))
        pauseItem = addItem("Pause desk timer", action: #selector(togglePause))
        menu.addItem(.separator())
        addItem("Settings…", action: #selector(showSettings), key: ",")
        loginItem = addItem("", action: #selector(openLoginItems))
        menu.addItem(.separator())
        addItem("Quit Take a Walk", action: #selector(quit), key: "q")
        statusItem.menu = menu

        reminder.onPrimary = { [weak self] in self?.primaryAction() }
        reminder.onSettings = { [weak self] in self?.showSettings() }
        reminder.onSilence = { [weak self] in self?.alarm.stop() }
        alarm.onChange = { [weak self] in self?.refresh() }
        preferences.onTestSound = { [weak self] in
            guard let self else { return }
            if self.alarm.isRinging { self.alarm.stop() } else { self.alarm.start() }
        }
        preferences.onSave = { [weak self] settings, loginWanted in
            guard let self else { return }
            self.engine.updateSettings(settings, now: Date())
            if !settings.soundEnabled { self.alarm.stop() }
            if !self.isPreview {
                self.defaults.set(try? JSONEncoder().encode(settings), forKey: "walkSettings")
                self.defaults.set(loginWanted, forKey: "startAtLogin")
                self.configureLogin(wanted: loginWanted)
            }
            self.refresh()
        }
        preferences.onOpenLoginSettings = { SMAppService.openSystemSettingsLoginItems() }

        if !isPreview {
            if defaults.object(forKey: "startAtLogin") == nil {
                defaults.set(true, forKey: "startAtLogin")
                configureLogin(wanted: true)
            }
            // Respect a later OS-level disable; never automatically re-register it.
            observeWorkspace()
            ticker = Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
            RunLoop.main.add(ticker!, forMode: .common)
            tick()
        } else {
            applyPreview()
        }
        refresh()
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func tick() {
        guard !sessionInactive, !systemSleeping else { return }
        let now = Date()
        // A missed workspace notification or a long process suspension should
        // never result in immediately ringing an overdue desk reminder on wake.
        if now.timeIntervalSince(lastTick) > 120 { engine.markAway() }
        lastTick = now
        let previousPhase = engine.phase
        let anyInput = CGEventType(rawValue: UInt32.max)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        if let event = engine.tick(now: now, idleSeconds: idle) {
            refresh()
            if event == .walkReminder || event == .walkFinished, engine.settings.soundEnabled { alarm.start() }
            reminder.show()
        } else {
            if engine.phase == .away, previousPhase != .away {
                alarm.stop()
                reminder.window.orderOut(nil)
            }
            refresh()
        }
    }

    private func refresh() {
        let now = Date()
        reminder.render(engine, now: now)
        reminder.setRinging(alarm.isRinging)
        preferences.updateAudioStatus(isRinging: alarm.isRinging, error: alarm.errorMessage)
        let state: String
        switch engine.phase {
        case .awaitingDesk: state = "Ready"; summaryItem.title = "Waiting for desk confirmation"
        case .away: state = "Away"; summaryItem.title = "Away · confirm when you're back"
        case .working: state = engine.countdown(now: now); summaryItem.title = "Next walk in \(state)"
        case .walkDue: state = "Walk"; summaryItem.title = "Time to take a walk"
        case .walking: state = engine.countdown(now: now); summaryItem.title = "Walking · \(state) remaining"
        case .breakFinished: state = "I'm back?"; summaryItem.title = "Walk finished · waiting for you"
        case .paused: state = "Ⅱ " + engine.countdown(now: now); summaryItem.title = "Desk timer paused"
        }
        statusItem.button?.title = " " + state
        statusItem.button?.toolTip = "Take a Walk · " + summaryItem.title
        statusItem.button?.setAccessibilityLabel("Take a Walk. " + summaryItem.title)
        pauseItem.title = engine.phase == .paused ? "Resume desk timer" : "Pause desk timer"
        pauseItem.isEnabled = engine.phase == .working || engine.phase == .paused
        walkItem.isEnabled = engine.phase == .working || engine.phase == .walkDue
        stopSoundItem.isEnabled = alarm.isRinging
        loginItem.title = loginStatus
    }

    private var loginStatus: String {
        if isPreview { return "Preview · login startup unchanged" }
        if let loginError { return "Login startup: \(loginError)" }
        switch SMAppService.mainApp.status {
        case .enabled: return "Start at login: on"
        case .requiresApproval: return "Start at login: needs approval…"
        case .notRegistered: return "Start at login: off"
        case .notFound: return "Start at login: app not found"
        @unknown default: return "Start at login: check System Settings…"
        }
    }

    private func configureLogin(wanted: Bool) {
        loginError = nil
        do {
            if wanted {
                if SMAppService.mainApp.status == .notRegistered || SMAppService.mainApp.status == .notFound {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginError = error.localizedDescription
        }
    }

    private func primaryAction() {
        alarm.stop()
        switch engine.phase {
        case .awaitingDesk, .away, .walking, .breakFinished:
            engine.confirmDesk(now: Date())
        case .working, .walkDue:
            engine.startWalk(now: Date())
        case .paused:
            engine.resume(now: Date())
        }
        reminder.window.orderOut(nil)
        refresh()
    }

    @objc private func showReminder() { refresh(); reminder.show() }
    @objc private func startWalk() { alarm.stop(); engine.startWalk(now: Date()); refresh(); reminder.show() }
    @objc private func stopRinging() { alarm.stop() }
    @objc private func togglePause() {
        alarm.stop()
        if engine.phase == .paused { engine.resume(now: Date()) } else { engine.pause(now: Date()) }
        refresh()
    }
    @objc private func showSettings() {
        preferences.show(settings: engine.settings, loginWanted: defaults.bool(forKey: "startAtLogin"), loginStatus: loginStatus)
    }
    @objc private func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func quit() { alarm.stop(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { alarm.stop() }
    func menuWillOpen(_ menu: NSMenu) { refresh() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showReminder()
        return true
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(sessionResigned), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(sessionBecameActive), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(sessionResigned),
            name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(sessionBecameActive),
            name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }
    @objc private func willSleep() { systemSleeping = true; handleAbsence() }
    @objc private func didWake() { systemSleeping = false; lastTick = Date() }
    @objc private func sessionResigned() { sessionInactive = true; handleAbsence() }
    @objc private func sessionBecameActive() { sessionInactive = false; lastTick = Date() }
    private func handleAbsence() {
        alarm.stop()
        engine.markAway()
        reminder.window.orderOut(nil)
        refresh()
    }

    private func applyPreview() {
        let args = ProcessInfo.processInfo.arguments
        let value = args.firstIndex(of: "--phase").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? "due"
        let now = Date()
        if value != "desk" { engine.confirmDesk(now: now.addingTimeInterval(-1800)) }
        if value == "working" { engine = WalkTimer(); engine.confirmDesk(now: now) }
        if value == "due" || value == "walking" || value == "back" {
            _ = engine.tick(now: now, idleSeconds: 0)
        }
        if value == "walking" { engine.startWalk(now: now) }
        if value == "back" {
            engine.startWalk(now: now.addingTimeInterval(-600))
            _ = engine.tick(now: now, idleSeconds: 0)
        }
        refresh()
        reminder.show()
    }
}
