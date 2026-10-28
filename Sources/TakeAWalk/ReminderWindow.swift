import AppKit
import WalkCore

@MainActor
final class ReminderWindow {
    let window = Theme.window(title: "Take a Walk", width: 470, height: 520)
    private let eyebrow = Theme.label("A LITTLE ROOM TO MOVE", size: 11, weight: .semibold, color: Theme.orange)
    private let symbol = NSImageView()
    private let heading = Theme.label("Back at your desk?", size: 29, weight: .bold)
    private let detail = Theme.label("", size: 14, color: Theme.muted)
    private let time = Theme.label("30:00", size: 62, weight: .light)
    private let caption = Theme.label("UNTIL YOUR NEXT WALK", size: 10, weight: .medium, color: Theme.muted)
    private let primary = ActionButton(title: "I'm at my desk", target: nil, action: nil)
    private let secondary = ActionButton(title: "Hide for now", target: nil, action: nil)
    var onPrimary: (() -> Void)?
    var onSettings: (() -> Void)?

    init() {
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let content = window.contentView!
        let settings = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")!,
                                target: self, action: #selector(openSettings))
        settings.isBordered = false
        settings.contentTintColor = Theme.muted
        settings.toolTip = "Settings"
        settings.setAccessibilityLabel("Settings")
        settings.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(settings)
        NSLayoutConstraint.activate([
            settings.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            settings.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            settings.widthAnchor.constraint(equalToConstant: 24),
            settings.heightAnchor.constraint(equalToConstant: 24)
        ])
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        symbol.contentTintColor = Theme.orange
        symbol.imageScaling = .scaleProportionallyUpOrDown
        symbol.setAccessibilityLabel("Walking reminder")
        symbol.widthAnchor.constraint(equalToConstant: 52).isActive = true
        symbol.heightAnchor.constraint(equalToConstant: 52).isActive = true
        time.font = .monospacedDigitSystemFont(ofSize: 62, weight: .light)
        time.setAccessibilityLabel("Countdown")
        primary.target = self
        primary.action = #selector(performPrimary)
        primary.keyEquivalent = "\r"
        secondary.secondary = true
        secondary.target = self
        secondary.action = #selector(hide)
        secondary.keyEquivalent = "\u{1b}"
        for view in [eyebrow, symbol, heading, detail, time, caption, primary, secondary] {
            stack.addArrangedSubview(view)
        }
        stack.setCustomSpacing(20, after: eyebrow)
        stack.setCustomSpacing(18, after: symbol)
        stack.setCustomSpacing(2, after: time)
        stack.setCustomSpacing(24, after: caption)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -36),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: 10),
            detail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            primary.widthAnchor.constraint(equalTo: stack.widthAnchor),
            primary.heightAnchor.constraint(equalToConstant: 48),
            secondary.widthAnchor.constraint(equalTo: stack.widthAnchor),
            secondary.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    func render(_ timer: WalkTimer, now: Date) {
        var image = "figure.walk"
        switch timer.phase {
        case .awaitingDesk, .away:
            eyebrow.stringValue = "LET'S FIND A GOOD RHYTHM"
            heading.stringValue = "Back at your desk?"
            detail.stringValue = "Settle in. We'll remind you to stretch your legs.\nPress Enter when you're ready."
            time.stringValue = String(format: "%02d:00", timer.settings.deskMinutes)
            caption.stringValue = "YOUR DESK TIMER"
            primary.title = "I'm at my desk"
        case .working:
            eyebrow.stringValue = "ONE THING AT A TIME"
            heading.stringValue = "You're in your rhythm."
            detail.stringValue = "A little focus now. A little fresh air soon."
            time.stringValue = timer.countdown(now: now)
            caption.stringValue = "UNTIL YOUR NEXT WALK"
            primary.title = "Start walk early"
        case .walkDue:
            eyebrow.stringValue = "TIME FOR A CHANGE OF SCENE"
            heading.stringValue = "Let's take a walk."
            detail.stringValue = "Step away, stretch your legs, and take\n\(timer.settings.walkMinutes) minutes for yourself."
            time.stringValue = String(format: "%02d:00", timer.settings.walkMinutes)
            caption.stringValue = "YOUR WALK STARTS WHEN YOU DO"
            primary.title = "Start walk"
        case .walking:
            eyebrow.stringValue = "A LITTLE ROOM TO BREATHE"
            heading.stringValue = "Enjoy your walk."
            detail.stringValue = "Your desk timer is on hold.\nCome back whenever you're ready."
            time.stringValue = timer.countdown(now: now)
            caption.stringValue = "LEFT IN YOUR WALK"
            primary.title = "I'm back"
        case .breakFinished:
            eyebrow.stringValue = "WELCOME BACK, WHEN YOU'RE READY"
            heading.stringValue = "Feeling refreshed?"
            detail.stringValue = "Your walk time is up. The next desk timer\nwill wait until you say you're back."
            time.stringValue = "00:00"
            caption.stringValue = "NO RUSH. YOUR TIMER IS WAITING."
            primary.title = "I'm back"
        case .paused:
            image = "pause.circle"
            eyebrow.stringValue = "TAKE YOUR TIME"
            heading.stringValue = "Timer paused."
            detail.stringValue = "Pick up where you left off\nwhenever you're ready."
            time.stringValue = timer.countdown(now: now)
            caption.stringValue = "REMAINING AT YOUR DESK"
            primary.title = "Resume timer"
        }
        symbol.image = NSImage(systemSymbolName: image, accessibilityDescription: "Take a Walk")
        primary.needsDisplay = true
    }

    func show() {
        // Put the prompt on the screen that currently contains the pointer.
        if !window.isVisible,
           let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) {
            let area = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2,
                                          y: area.midY - window.frame.height / 2))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func performPrimary() { onPrimary?() }
    @objc private func openSettings() { onSettings?() }
    @objc private func hide() { window.orderOut(nil) }
}
