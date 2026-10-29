import AppKit
import WalkCore

@MainActor
final class SettingsWindow {
    let window = Theme.window(title: "Take a Walk Settings", width: 440, height: 555)
    private let desk = NSTextField(string: "30")
    private let walk = NSTextField(string: "10")
    private let away = NSTextField(string: "10")
    private let sound = NSButton(checkboxWithTitle: "Play reminder sounds", target: nil, action: nil)
    private let testSound = NSButton(title: "Test ringing", target: nil, action: nil)
    private let audioStatus = Theme.label("", size: 12, color: Theme.muted)
    private let login = NSButton(checkboxWithTitle: "Start when I log in to this Mac", target: nil, action: nil)
    private let status = Theme.label("", size: 12, color: Theme.muted)
    private let validation = Theme.label("", size: 12, color: Theme.orange)
    var onSave: ((WalkSettings, Bool) -> Void)?
    var onOpenLoginSettings: (() -> Void)?
    var onTestSound: (() -> Void)?

    init() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(stack)
        let title = Theme.label("Make it your rhythm.", size: 24, weight: .bold)
        title.alignment = .left
        stack.addArrangedSubview(title)
        for (name, field, range) in [("Desk timer", desk, "1–240 min"),
                                      ("Walk time", walk, "1–60 min"),
                                      ("Mark away after", away, "1–120 min")] {
            let label = Theme.label(name, size: 14)
            label.alignment = .left
            label.widthAnchor.constraint(equalToConstant: 155).isActive = true
            field.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
            field.alignment = .center
            field.widthAnchor.constraint(equalToConstant: 60).isActive = true
            field.setAccessibilityLabel(name + " in minutes")
            let units = Theme.label(range, size: 11, color: Theme.muted)
            let row = NSStackView(views: [label, field, units])
            row.spacing = 10
            stack.addArrangedSubview(row)
        }
        sound.contentTintColor = Theme.white
        login.contentTintColor = Theme.white
        testSound.target = self
        testSound.action = #selector(toggleTestSound)
        testSound.bezelStyle = .rounded
        let soundRow = NSStackView(views: [sound, testSound])
        soundRow.spacing = 16
        stack.addArrangedSubview(soundRow)
        audioStatus.alignment = .left
        stack.addArrangedSubview(audioStatus)
        stack.addArrangedSubview(login)
        status.alignment = .left
        stack.addArrangedSubview(status)
        let systemSettings = NSButton(title: "Open macOS Login Items…", target: self, action: #selector(openLoginSettings))
        systemSettings.bezelStyle = .inline
        stack.addArrangedSubview(systemSettings)
        let note = Theme.label("Changing the desk duration restarts a running desk timer. Settings stay on this Mac.", size: 12, color: Theme.muted)
        note.alignment = .left
        stack.addArrangedSubview(note)
        validation.alignment = .left
        stack.addArrangedSubview(validation)
        let save = ActionButton(title: "Save settings", target: self, action: #selector(saveSettings))
        save.keyEquivalent = "\r"
        stack.addArrangedSubview(save)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 42),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
            audioStatus.widthAnchor.constraint(equalTo: stack.widthAnchor),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor),
            validation.widthAnchor.constraint(equalTo: stack.widthAnchor),
            save.widthAnchor.constraint(equalTo: stack.widthAnchor),
            save.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func updateAudioStatus(isRinging: Bool, error: String?) {
        testSound.title = isRinging ? "Stop ringing" : "Test ringing"
        audioStatus.stringValue = error ?? (isRinging
            ? "Ringing for up to 1 minute. Click Stop ringing to silence it."
            : "Repeats for up to 1 minute. Uses your Mac's output volume.")
        audioStatus.textColor = error == nil ? Theme.muted : Theme.orange
    }

    @objc private func toggleTestSound() { onTestSound?() }

    func show(settings: WalkSettings, loginWanted: Bool, loginStatus: String) {
        desk.stringValue = String(settings.deskMinutes)
        walk.stringValue = String(settings.walkMinutes)
        away.stringValue = String(settings.awayMinutes)
        sound.state = settings.soundEnabled ? .on : .off
        login.state = loginWanted ? .on : .off
        status.stringValue = loginStatus
        validation.stringValue = ""
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openLoginSettings() { onOpenLoginSettings?() }

    @objc private func saveSettings() {
        guard let deskValue = Int(desk.stringValue.trimmingCharacters(in: .whitespaces)), (1...240).contains(deskValue),
              let walkValue = Int(walk.stringValue.trimmingCharacters(in: .whitespaces)), (1...60).contains(walkValue),
              let awayValue = Int(away.stringValue.trimmingCharacters(in: .whitespaces)), (1...120).contains(awayValue) else {
            validation.stringValue = "Enter whole minutes within the ranges shown above."
            return
        }
        onSave?(WalkSettings(deskMinutes: deskValue, walkMinutes: walkValue,
                             awayMinutes: awayValue, soundEnabled: sound.state == .on), login.state == .on)
        window.orderOut(nil)
    }
}
