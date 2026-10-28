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
- The user can hide a popup and reopen it from the menu bar. A sound plays once per reminder, not repeatedly.

## First draft verification

- Release build succeeds with no compiler warnings; installed app and preview pass strict code-signature verification.
- All 13 deterministic timer checks pass, covering explicit confirmation, one-shot reminders, walks, return, inactivity, sleep handling, pause/resume, and settings changes.
- Native UI inspection verified the dark navy/tangerine reminder and Settings layout, Start walk, Enter, I'm back, invalid duration rejection, and applying a new duration to the next desk session.
- System idle-time access was checked successfully on the development Mac.
- Login after logout, sound audibility, popup behavior in full-screen apps, and running on the second Mac still need user acceptance testing.
- The normal app is installed but has not been launched during verification. The preview does not register login startup or change saved preferences.
