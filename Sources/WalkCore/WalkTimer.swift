import Foundation

public struct WalkSettings: Codable, Equatable, Sendable {
    public var deskMinutes: Int
    public var walkMinutes: Int
    public var awayMinutes: Int
    public var soundEnabled: Bool

    public init(deskMinutes: Int = 30, walkMinutes: Int = 10,
                awayMinutes: Int = 10, soundEnabled: Bool = true) {
        self.deskMinutes = min(240, max(1, deskMinutes))
        self.walkMinutes = min(60, max(1, walkMinutes))
        self.awayMinutes = min(120, max(1, awayMinutes))
        self.soundEnabled = soundEnabled
    }
}

public struct WalkTimer: Sendable {
    public enum Phase: Equatable, Sendable {
        case awaitingDesk, working, walkDue, walking, breakFinished, away, paused
    }

    public enum Event: Equatable, Sendable {
        case confirmDesk, walkReminder, walkFinished
    }

    public private(set) var phase: Phase = .awaitingDesk
    public private(set) var settings: WalkSettings
    private var deadline: Date?
    private var pausedRemaining: TimeInterval = 0
    private var deskPromptSent = false

    public init(settings: WalkSettings = WalkSettings()) {
        self.settings = settings
    }

    /// Called with the system's elapsed time since any keyboard/mouse input.
    /// Reading idle time does not read or store the input itself.
    public mutating func tick(now: Date, idleSeconds: TimeInterval) -> Event? {
        if (phase == .awaitingDesk || phase == .away),
           idleSeconds >= Double(settings.awayMinutes * 60) {
            deskPromptSent = false
        }
        if (phase == .working || phase == .walkDue),
           idleSeconds >= Double(settings.awayMinutes * 60) {
            markAway()
        }

        switch phase {
        case .awaitingDesk, .away:
            if idleSeconds < 2, !deskPromptSent {
                deskPromptSent = true
                return .confirmDesk
            }
        case .working:
            if let deadline, now >= deadline {
                phase = .walkDue
                self.deadline = nil
                return .walkReminder
            }
        case .walking:
            if let deadline, now >= deadline {
                phase = .breakFinished
                self.deadline = nil
                return .walkFinished
            }
        case .walkDue, .breakFinished, .paused:
            break
        }
        return nil
    }

    public mutating func confirmDesk(now: Date) {
        guard [.awaitingDesk, .away, .walking, .breakFinished].contains(phase) else { return }
        phase = .working
        deadline = now.addingTimeInterval(Double(settings.deskMinutes * 60))
    }

    public mutating func startWalk(now: Date) {
        guard phase == .working || phase == .walkDue else { return }
        phase = .walking
        deadline = now.addingTimeInterval(Double(settings.walkMinutes * 60))
    }

    public mutating func markAway() {
        guard phase == .working || phase == .walkDue || phase == .awaitingDesk || phase == .away else { return }
        phase = .away
        deadline = nil
        deskPromptSent = false
    }

    public mutating func pause(now: Date) {
        guard phase == .working else { return }
        pausedRemaining = max(0, deadline?.timeIntervalSince(now) ?? 0)
        deadline = nil
        phase = .paused
    }

    public mutating func resume(now: Date) {
        guard phase == .paused else { return }
        phase = .working
        deadline = now.addingTimeInterval(pausedRemaining)
    }

    /// A changed desk duration restarts a running desk timer. An ongoing walk
    /// and a manually paused desk timer retain their remaining time.
    public mutating func updateSettings(_ settings: WalkSettings, now: Date) {
        let durationChanged = self.settings.deskMinutes != settings.deskMinutes
        self.settings = settings
        if phase == .working, durationChanged {
            deadline = now.addingTimeInterval(Double(settings.deskMinutes * 60))
        }
    }

    public func remainingSeconds(now: Date) -> Int {
        if phase == .paused { return Int(ceil(pausedRemaining)) }
        guard let deadline else { return 0 }
        return max(0, Int(ceil(deadline.timeIntervalSince(now))))
    }

    public func countdown(now: Date) -> String {
        let seconds = remainingSeconds(now: now)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
