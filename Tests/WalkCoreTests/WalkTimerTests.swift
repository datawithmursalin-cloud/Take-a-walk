import Foundation
import WalkCore

private let start = Date(timeIntervalSince1970: 1_800_000_000)

func waitsForExplicitDeskConfirmation() {
    var timer = WalkTimer()
    expect(timer.tick(now: start, idleSeconds: 20) == nil)
    expect(timer.tick(now: start, idleSeconds: 0) == .confirmDesk)
    expect(timer.tick(now: start.addingTimeInterval(1), idleSeconds: 0) == nil)
    expect(timer.phase == .awaitingDesk)
    expect(timer.remainingSeconds(now: start) == 0)
    timer.confirmDesk(now: start)
    expect(timer.countdown(now: start) == "30:00")
}

func oneReminderAtDeadlineAndNoAutomaticWalk() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    expect(timer.tick(now: start.addingTimeInterval(1799), idleSeconds: 0) == nil)
    expect(timer.countdown(now: start.addingTimeInterval(1799.2)) == "00:01")
    expect(timer.tick(now: start.addingTimeInterval(1800), idleSeconds: 0) == .walkReminder)
    expect(timer.phase == .walkDue)
    expect(timer.tick(now: start.addingTimeInterval(1801), idleSeconds: 0) == nil)
    expect(timer.tick(now: start.addingTimeInterval(2500), idleSeconds: 0) == nil)
    expect(timer.phase == .walkDue)
}

func walkStartsWhenClickedAndWaitsForReturn() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    _ = timer.tick(now: start.addingTimeInterval(1800), idleSeconds: 0)
    let clicked = start.addingTimeInterval(1900)
    timer.startWalk(now: clicked)
    expect(timer.countdown(now: clicked) == "10:00")
    expect(timer.tick(now: clicked.addingTimeInterval(599), idleSeconds: 900) == nil)
    expect(timer.tick(now: clicked.addingTimeInterval(600), idleSeconds: 1200) == .walkFinished)
    expect(timer.tick(now: clicked.addingTimeInterval(900), idleSeconds: 0) == nil)
    expect(timer.phase == .breakFinished)
    let returned = clicked.addingTimeInterval(1200)
    timer.confirmDesk(now: returned)
    expect(timer.phase == .working)
    expect(timer.countdown(now: returned) == "30:00")
}

func inputDuringWalkDoesNotAutomaticallyRestartDeskTimer() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    timer.startWalk(now: start)
    expect(timer.tick(now: start.addingTimeInterval(300), idleSeconds: 0) == nil)
    expect(timer.phase == .walking)
    timer.confirmDesk(now: start.addingTimeInterval(300))
    expect(timer.countdown(now: start.addingTimeInterval(300)) == "30:00")
}

func idleWinsOverOverdueDeskReminder() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    expect(timer.tick(now: start.addingTimeInterval(1800), idleSeconds: 600) == nil)
    expect(timer.phase == .away)
    expect(timer.tick(now: start.addingTimeInterval(1801), idleSeconds: 0) == .confirmDesk)
    expect(timer.phase == .away)
    timer.confirmDesk(now: start.addingTimeInterval(1802))
    expect(timer.countdown(now: start.addingTimeInterval(1802)) == "30:00")
}

func dismissedDeskPromptCanReappearAfterAnotherAbsence() {
    var timer = WalkTimer()
    expect(timer.tick(now: start, idleSeconds: 0) == .confirmDesk)
    expect(timer.tick(now: start.addingTimeInterval(600), idleSeconds: 600) == nil)
    expect(timer.tick(now: start.addingTimeInterval(601), idleSeconds: 0) == .confirmDesk)
}

func eachReturnPromptsOnlyOnce() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    timer.markAway()
    expect(timer.tick(now: start, idleSeconds: 0) == .confirmDesk)
    expect(timer.tick(now: start.addingTimeInterval(1), idleSeconds: 0) == nil)
    _ = timer.tick(now: start.addingTimeInterval(700), idleSeconds: 700)
    expect(timer.tick(now: start.addingTimeInterval(701), idleSeconds: 0) == .confirmDesk)
}

func manualPausePreservesRemainingTime() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    timer.pause(now: start.addingTimeInterval(120))
    expect(timer.countdown(now: start.addingTimeInterval(9000)) == "28:00")
    expect(timer.tick(now: start.addingTimeInterval(9000), idleSeconds: 9000) == nil)
    expect(timer.phase == .paused)
    timer.resume(now: start.addingTimeInterval(9000))
    expect(timer.tick(now: start.addingTimeInterval(10679), idleSeconds: 0) == nil)
    expect(timer.tick(now: start.addingTimeInterval(10680), idleSeconds: 0) == .walkReminder)
}

func sleepDuringWorkRequiresNewConfirmation() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    timer.markAway()
    expect(timer.phase == .away)
    expect(timer.tick(now: start.addingTimeInterval(7200), idleSeconds: 0) == .confirmDesk)
    expect(timer.phase == .away)
}

func sleepDuringWalkPreservesBreakAndReturnRequirement() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    timer.startWalk(now: start)
    timer.markAway()
    expect(timer.phase == .walking)
    expect(timer.tick(now: start.addingTimeInterval(7200), idleSeconds: 0) == .walkFinished)
    expect(timer.phase == .breakFinished)
}

func settingsChangeRestartsActiveDeskTimerButNotWalk() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    let changed = start.addingTimeInterval(300)
    timer.updateSettings(WalkSettings(deskMinutes: 45, walkMinutes: 5), now: changed)
    expect(timer.countdown(now: changed) == "45:00")
    timer.startWalk(now: changed)
    timer.updateSettings(WalkSettings(deskMinutes: 60, walkMinutes: 20), now: changed.addingTimeInterval(60))
    expect(timer.countdown(now: changed.addingTimeInterval(60)) == "04:00")
    timer.confirmDesk(now: changed.addingTimeInterval(60))
    expect(timer.countdown(now: changed.addingTimeInterval(60)) == "60:00")
}

func changingSoundDoesNotResetWork() {
    var timer = WalkTimer()
    timer.confirmDesk(now: start)
    timer.updateSettings(WalkSettings(soundEnabled: false), now: start.addingTimeInterval(60))
    expect(timer.countdown(now: start.addingTimeInterval(60)) == "29:00")
}

func invalidTransitionsCannotSkipDeskConfirmation() {
    var timer = WalkTimer()
    timer.startWalk(now: start)
    timer.resume(now: start)
    timer.pause(now: start)
    expect(timer.phase == .awaitingDesk)
    timer.confirmDesk(now: start)
    timer.confirmDesk(now: start.addingTimeInterval(120))
    expect(timer.countdown(now: start.addingTimeInterval(120)) == "28:00")
}


func expect(_ condition: @autoclosure () -> Bool,
                    file: StaticString = #filePath, line: UInt = #line) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAIL: \(file):\(line)\n".utf8))
        exit(1)
    }
}

@main
struct WalkCoreChecks {
    @MainActor
    static func main() {
        let tests: [(String, () -> Void)] = [
            ("Waits for explicit desk confirmation", waitsForExplicitDeskConfirmation),
            ("One reminder; no automatic walk", oneReminderAtDeadlineAndNoAutomaticWalk),
            ("Walk starts on click; waits for return", walkStartsWhenClickedAndWaitsForReturn),
            ("Input during walk does not restart work", inputDuringWalkDoesNotAutomaticallyRestartDeskTimer),
            ("Idle beats overdue reminder", idleWinsOverOverdueDeskReminder),
            ("Desk prompt reappears after another absence", dismissedDeskPromptCanReappearAfterAnotherAbsence),
            ("Each return prompts once", eachReturnPromptsOnlyOnce),
            ("Manual pause preserves remaining time", manualPausePreservesRemainingTime),
            ("Sleep during work requires confirmation", sleepDuringWorkRequiresNewConfirmation),
            ("Sleep during walk preserves return requirement", sleepDuringWalkPreservesBreakAndReturnRequirement),
            ("Settings apply correctly to work and walking", settingsChangeRestartsActiveDeskTimerButNotWalk),
            ("Sound setting preserves work countdown", changingSoundDoesNotResetWork),
            ("Invalid transitions cannot skip confirmation", invalidTransitionsCannotSkipDeskConfirmation),
            ("Ringing stops at one minute", ringingStopsAtOneMinuteWithoutRepeatingTheNotification),
            ("Acknowledgment stops and releases audio", acknowledgedAlarmStopsAndReleasesItsPlayer),
            ("Restarted alarm gets a full minute", restartingAnAlarmGetsItsOwnFullMinute),
            ("Failed playback is reported", failedAudioStartIsReportedWithoutClaimingToRing),
            ("Interrupted playback is cleaned up", interruptedAudioIsReportedAndCleanedUp),
            ("Bell decodes as non-silent audio", generatedBellDecodesAsTwoSecondsOfNonSilentAudio)
        ]
        for (name, test) in tests {
            test()
            print("PASS: \(name)")
        }
        print("\(tests.count) checks passed.")
    }
}
