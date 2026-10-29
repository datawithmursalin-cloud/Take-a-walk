import AVFAudio
import Foundation

@MainActor
public protocol ReminderPlayback: AnyObject {
    var isPlaying: Bool { get }
    func prepareToPlay() -> Bool
    func play() -> Bool
    func stop()
}

extension AVAudioPlayer: ReminderPlayback {}

/// Owns the player for its entire lifetime and bounds every ring to one minute.
@MainActor
public final class ReminderAlarm: NSObject {
    public private(set) var isRinging = false
    public private(set) var errorMessage: String?
    public var onChange: (() -> Void)?
    private let makePlayer: () throws -> any ReminderPlayback
    private let uptime: () -> TimeInterval
    private var player: (any ReminderPlayback)?
    private var deadline: TimeInterval?
    private var timeout: Timer?

    public override convenience init() {
        self.init(makePlayer: {
            let player = try AVAudioPlayer(data: ReminderTone.wavData())
            player.numberOfLoops = -1
            player.volume = 1
            return player
        })
    }

    public init(makePlayer: @escaping () throws -> any ReminderPlayback,
                uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.makePlayer = makePlayer
        self.uptime = uptime
        super.init()
    }

    @discardableResult
    public func start() -> Bool {
        stop()
        errorMessage = nil
        do {
            let audio = try makePlayer()
            player = audio
            guard audio.prepareToPlay(), audio.play() else {
                audio.stop()
                player = nil
                errorMessage = "Audio could not start. Check your Mac's sound output and try again."
                onChange?()
                return false
            }
            deadline = uptime() + 60
            isRinging = true
            let timer = Timer(timeInterval: 0.25, target: self, selector: #selector(checkTimeout), userInfo: nil, repeats: true)
            timer.tolerance = 0.05
            timeout = timer
            RunLoop.main.add(timer, forMode: .common)
            onChange?()
            return true
        } catch {
            player = nil
            errorMessage = "Audio could not load: \(error.localizedDescription)"
            onChange?()
            return false
        }
    }

    public func stop() {
        timeout?.invalidate()
        timeout = nil
        deadline = nil
        player?.stop()
        player = nil
        let wasRinging = isRinging
        isRinging = false
        if wasRinging { onChange?() }
    }

    @objc public func checkTimeout() {
        guard let deadline else { return }
        if uptime() >= deadline {
            stop()
        } else if player?.isPlaying != true {
            errorMessage = "Audio playback stopped. Check your Mac's sound output and try again."
            stop()
        }
    }
}
