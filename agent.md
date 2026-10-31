# Take a Walk — project instructions

## Agreed scope

- Local, native macOS menu bar app. Build work was authorized during the voice discussion.
- Run the same source on both the Mac Mini and MacBook Air. Timers, preferences, and login startup are independent per device; desk confirmation prevents automatically starting a timer while using the laptop in bed.
- Dark navy interface, tangerine accents, warm white text, large countdown.
- Start at login, detect desk presence using macOS idle time, and ask the user to confirm with Enter or “I'm at my desk.” Do not record keyboard input or mouse positions.
- Default desk timer: 30 minutes. Show a foreground popup and play a sound when it expires.
- Clicking “Start walk” begins a 10-minute walk. Never infer that a walk started merely because a reminder appeared.
- After the walk, wait for “I'm back” before starting a fresh desk timer.
- Ten minutes without input counts as away. On return, ask for confirmation before starting a fresh desk timer. Sleep and screen lock also mark a working session as away.
- Show a countdown in the menu bar. Provide settings, pause/resume, and quit.
- Timer durations are adjustable and settings persist locally. No accounts, servers, telemetry, or third-party dependencies.

## Working agreement

- Keep this file current as scope or implementation decisions change.
- Always ask the user which files and folders they want excluded before changing `.gitignore`. The user approved `.DS_Store`, `.env` secrets, logs, generated build outputs, and dependency folders, with nothing else for now.
- Use deterministic tests for timer behavior. Build the native app and inspect its UI before delivery when computer access allows it.
- The user requires explicit confirmation before committing or pushing. After the first draft summary, the user explicitly authorized committing this draft and pushing it to `main` in `datawithmursalin-cloud/Take-a-walk`, so they can clone it on the MacBook Air. This authorizes the current delivery; seek confirmation again for future commits or pushes.

## Implementation

- Swift Package: `WalkCore` contains the timer state machine; `TakeAWalk` contains the AppKit interface and macOS integrations.
- `./run.command` builds a signed local app bundle and launches it. `./scripts/test.sh` runs the timer tests.
- Install generated bundles under `~/Applications`, outside iCloud. Building app bundles in the iCloud source folder caused Finder metadata to fail strict code-signature verification.
- The test script runs a small executable harness with deterministic checks; it requires only Command Line Tools, without an Xcode test runner or third-party package.
- Login startup uses `SMAppService`; reflect its actual status and expose macOS Login Items settings if approval is needed.
- The user can hide a popup and reopen it from the menu bar. Following live testing, the user requested a repeating one-minute ring instead of the original single chime.
- `ReminderAudio` generates a bell locally and retains an AVAudioPlayer for playback. Ring for up to 60 seconds at both desk and walk deadlines; stop on acknowledgment, explicit Stop ringing, popup close, sound disable, sleep/lock, or quit. Settings includes Test ringing and playback error feedback. Never change system volume.

## First draft verification

- Release build succeeds with no compiler warnings; installed app and preview pass strict code-signature verification.
- All 13 deterministic timer checks pass, covering explicit confirmation, one-shot reminders, walks, return, inactivity, sleep handling, pause/resume, and settings changes.
- Native UI inspection verified the dark navy/tangerine reminder and Settings layout, Start walk, Enter, I'm back, invalid duration rejection, and applying a new duration to the next desk session.
- System idle-time access was checked successfully on the development Mac.
- Login after logout, sound audibility, popup behavior in full-screen apps, and running on the second Mac still need user acceptance testing.
- The normal app is installed but has not been launched during verification. The preview does not register login startup or change saved preferences.

## Live test and audio update

- The user confirmed the reminder cycle worked on the Mac Mini but could not hear the original single system chime.
- The user requested ringing for one minute. The new generated double bell, retained AVAudioPlayer, Stop ringing controls, and Settings sound test are implemented and installed locally.
- All 19 checks pass, including audio decoding, the 60-second cutoff, cancellation/player lifetime, restarted alarms, and failed/interrupted playback. Release build and strict code-signature verification pass. Updated Settings layout was visually inspected.
- The user prefers guidance while they click through live tests. Settings is open with Test ringing ready; actual audibility still needs their confirmation. Startup currently reports on; an actual logout/login test is still pending.
- Current local test settings are desk = 1 minute, walk = 1 minute, away = 10 minutes, sound enabled. Restore desk = 30 and walk = 10 when the guided test is complete.
- After reviewing the audio and logo updates, the user explicitly authorized committing and pushing all current work to `main` as the final delivery.

## App logo

- The user supplied the orange walking figure on navy and requested it as the app logo.
- Recreated the reference as original vector paths, retaining its sampled colors. Source: `Resources/Brand/Logo.svg`; reference: `Resources/Brand/Reference.png`; exports: `Resources/AppIcon.png` (1024px) and `Resources/AppIcon.icns` (all standard macOS sizes).
- `scripts/generate-icon.swift` regenerates the assets using AppKit and iconutil; temporary iconsets stay in the already ignored `.build` folder. No `.gitignore` changes were needed.
- The bundle declares `CFBundleIconFile = AppIcon`, and the build script installs the `.icns` in Contents/Resources. The user explicitly authorized including these assets in the final commit and push to `main`.
- Installed the updated app after the user confirmed it was closed. Verified the bundled icon matches the source, strict code-signature validation passes, and Finder's Get Info window displays the walking logo.

## Final delivery

- On 2026-10-29, the user approved committing the completed ringing and logo updates and pushing to `main`, then declared project work finished.
- Before publication, the user requested a detailed public-facing README explaining the motivation and purpose, then reaffirmed authorization to commit and push to `main`. The README also covers features, setup, daily use, privacy, development, troubleshooting, and current acceptance-test limits.
- Final validation: all 19 checks pass, shell syntax and Info.plist validate, and the installed app passes strict code-signature verification.
- Keep build caches, generated iconsets, and local preferences out of Git. Preserve the agreed `.gitignore`; ask before changing its exclusions.
- Actual sound audibility, login after logout, full-screen behavior, and second-device acceptance remain user checks. Future commits or pushes still require fresh user confirmation.

## Menu bar actions

- On 2026-10-31, fetched and pulled `main` at the user's request; the checkout was already up to date.
- The menu starts with **Start Walk Now** and **I'm Back on My Desk**, ahead of the status summary and other controls. Enable actions only in the corresponding timer phases; desk confirmation also works on initial launch and after absence.
- Both actions stop ringing and dismiss the reminder without opening or activating the app window. A due reminder still waits for explicit walk start, allowing the user to finish work first and start the walk later from the menu.
- Menu bar **Stop ringing** also hides the popup while preserving the pending walk, so postponing the walk requires no interaction with the app window.
- Updated and signature-verified both `~/Applications/Take a Walk.app` and the user's running copy at `/Applications/Take a Walk.app`; restarted the normal app after closing the preview. Restarting resets the in-memory countdown and waits for desk confirmation.
- All 19 deterministic checks and the release build pass. Native reminder preview was inspected; the UI tool timed out accessing system menu bar surfaces, so visual menu verification remains a user check.
- The user explicitly authorized committing and pushing these menu bar updates to `main` on 2026-10-31.
