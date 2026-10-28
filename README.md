# Take a Walk

A small, local macOS menu bar app that reminds you to leave your chair. Navy, tangerine, and a little room to move.

## Run it

Requires macOS 13 or later and Apple's Command Line Tools with Swift 6 or later. Builds for Apple silicon and Intel Macs; build on each Mac to use its native architecture.

1. If needed, install the tools: `xcode-select --install`.
2. Open this folder in Terminal and run `./run.command`, or double-click `run.command` in Finder.
3. Look for the walking icon in the menu bar. Confirm **I'm at my desk** (or press Enter) to start.

The first build can take a minute. The launcher installs the app at `~/Applications/Take a Walk.app` to keep it outside iCloud and give login startup a stable location. Later, open that app directly; rebuilding isn't necessary unless the source changed. Quit the running app before rebuilding it after a source update.

## Your rhythm

- **Desk:** 30 minutes by default. A popup with a single chime asks you to walk.
- **Walk:** Click **Start walk** to begin a 10-minute countdown. The desk timer stays on hold.
- **Return:** When the walk ends, another popup and chime appear. A fresh desk timer starts only after you click **I'm back**. You can also return early.
- **Away:** After 10 minutes without mouse or keyboard input, the app marks you away. When input resumes, confirm you're at your desk to start a fresh timer. Sleep and screen lock also end a working desk session.
- **Controls:** Use the menu bar for the countdown, **Show Take a Walk**, **Start walk now**, **Pause desk timer**, **Settings**, or **Quit**. The gear in the popup also opens Settings. Hiding a popup doesn't quit the app or start a walk.

Settings let you change the desk, walk, and inactivity durations, mute reminder sounds, and control login startup. A changed desk duration restarts a running desk timer; an ongoing walk keeps its original remaining time. After relaunch, the app waits for desk confirmation again.

## Login startup

The first normal launch requests startup at login using macOS Login Items. Check the actual status in the app's menu. If macOS requires approval, use **Settings → Open macOS Login Items…** to enable it. You can turn startup off in the app or System Settings. Keep the built app at a stable location; moving or deleting it can interrupt login startup. If you change its location, open it there and re-enable startup in Settings.

Login startup is requested only on the first normal launch or when you explicitly enable it in Settings. The app respects later OS-level disabling. Login behavior needs an actual logout/login check on your Mac; unit tests cannot verify it.

## Mac Mini and MacBook Air

Use the same source folder or pull the repository on each Mac, then run `./run.command` there. Each device has its own timer, settings, and login preference; sessions do not sync. On your laptop, hide the desk prompt or turn off login startup if you're using it away from your desk.

On a new Mac, clone and run:

```sh
git clone https://github.com/datawithmursalin-cloud/Take-a-walk.git
cd Take-a-walk
./run.command
```

For an existing checkout, quit the app, run `git pull --ff-only`, and run `./run.command` again to install the updated version.

Only system idle duration is read. The app doesn't record keys, mouse positions, screenshots, or browsing activity and makes no network requests. Preferences are stored in macOS UserDefaults under `local.takeawalk.app`.

## Development and preview

```sh
./scripts/test.sh
./scripts/build.sh --preview
open "$HOME/Applications/Take a Walk Preview.app"
```

Preview phases: `desk`, `working`, `due`, `walking`, and `back`; pass `--args --phase desk` to the `open` command to choose a phase when launching. Preview doesn't register a login item, save settings, play sounds, or run the automatic timer. It is a safe way to review the interface before using the app. Quit the preview before opening the normal app.

The timer state machine is in `Sources/WalkCore`; native AppKit windows and macOS integrations are in `Sources/TakeAWalk`. There are no third-party dependencies. The build is locally ad-hoc signed rather than notarized for distribution.

Project decisions and collaboration rules live in `agent.md`. Git commits and pushes require the user's explicit confirmation.
