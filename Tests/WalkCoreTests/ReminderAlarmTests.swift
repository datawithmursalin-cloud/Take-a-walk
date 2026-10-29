import AVFAudio
import Foundation
import ReminderAudio

@MainActor
private final class FakePlayback: ReminderPlayback {
    var isPlaying = false
    var canPrepare = true
    var canPlay = true
    var stopCount = 0
    func prepareToPlay() -> Bool { canPrepare }
    func play() -> Bool { isPlaying = canPlay; return canPlay }
    func stop() { isPlaying = false; stopCount += 1 }
}

@MainActor
func ringingStopsAtOneMinuteWithoutRepeatingTheNotification() {
    let player = FakePlayback()
    var clock = 100.0
    var changes = 0
    let alarm = ReminderAlarm(makePlayer: { player }, uptime: { clock })
    alarm.onChange = { changes += 1 }
    expect(alarm.start())
    expect(alarm.isRinging && player.isPlaying)
    clock = 159.999
    alarm.checkTimeout()
    expect(alarm.isRinging)
    clock = 160
    alarm.checkTimeout()
    expect(!alarm.isRinging && !player.isPlaying)
    expect(changes == 2)
    alarm.checkTimeout()
    expect(changes == 2)
}

@MainActor
func acknowledgedAlarmStopsAndReleasesItsPlayer() {
    weak var observed: FakePlayback?
    let alarm = ReminderAlarm(makePlayer: {
        let audio = FakePlayback()
        observed = audio
        return audio
    })
    expect(alarm.start())
    expect(observed?.isPlaying == true)
    alarm.stop()
    expect(observed == nil)
    expect(!alarm.isRinging)
}

@MainActor
func restartingAnAlarmGetsItsOwnFullMinute() {
    var clock = 0.0
    let old = FakePlayback()
    let next = FakePlayback()
    var calls = 0
    let alarm = ReminderAlarm(makePlayer: {
        calls += 1
        return calls == 1 ? old : next
    }, uptime: { clock })
    expect(alarm.start())
    clock = 40
    expect(alarm.start())
    expect(!old.isPlaying && next.isPlaying)
    clock = 60
    alarm.checkTimeout()
    expect(alarm.isRinging)
    clock = 100
    alarm.checkTimeout()
    expect(!alarm.isRinging && !next.isPlaying)
}

@MainActor
func failedAudioStartIsReportedWithoutClaimingToRing() {
    let player = FakePlayback()
    player.canPlay = false
    let alarm = ReminderAlarm(makePlayer: { player })
    expect(!alarm.start())
    expect(!alarm.isRinging)
    expect(alarm.errorMessage != nil)
    player.canPlay = true
    expect(alarm.start())
    expect(alarm.errorMessage == nil)
    alarm.stop()
}

@MainActor
func interruptedAudioIsReportedAndCleanedUp() {
    let player = FakePlayback()
    let alarm = ReminderAlarm(makePlayer: { player })
    expect(alarm.start())
    player.isPlaying = false
    alarm.checkTimeout()
    expect(!alarm.isRinging)
    expect(alarm.errorMessage != nil)
}

func generatedBellDecodesAsTwoSecondsOfNonSilentAudio() {
    let data = ReminderTone.wavData()
    do {
        let decoded = try AVAudioPlayer(data: data)
        expect(abs(decoded.duration - 2) < 0.001)
        expect(decoded.numberOfChannels == 1)
        let pcm = Array(data.dropFirst(44))
        var peak = 0
        for index in stride(from: 0, to: pcm.count - 1, by: 2) {
            let sample = Int16(bitPattern: UInt16(pcm[index]) | UInt16(pcm[index + 1]) << 8)
            peak = max(peak, abs(Int(sample)))
        }
        expect(peak > 10_000 && peak < Int(Int16.max))
    } catch {
        expect(false)
    }
}
