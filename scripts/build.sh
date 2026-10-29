#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p .build/module-cache .build/cache .build/config .build/security
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/module-cache"
swift build --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security -c release --product TakeAWalk
app_name="Take a Walk"
bundle_id="local.takeawalk.app"
if [ "${1:-}" = "--preview" ]; then
    app_name="Take a Walk Preview"
    bundle_id="local.takeawalk.preview"
fi
app_dir="$HOME/Applications/$app_name.app"
if [ -e "$app_dir" ]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_dir/Contents/Info.plist" 2>/dev/null || true)"
    if [ "$existing_id" != "$bundle_id" ]; then
        printf 'Another app already exists at %s; choose a different location before building.\n' "$app_dir" >&2
        exit 1
    fi
fi
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp .build/release/TakeAWalk "$app_dir/Contents/MacOS/TakeAWalk"
cp Resources/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $app_name" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $app_name" "$app_dir/Contents/Info.plist"
if [ "${1:-}" = "--preview" ]; then
    /usr/libexec/PlistBuddy -c "Add :TakeAWalkPreview bool true" "$app_dir/Contents/Info.plist"
fi
# Finder/iCloud may add metadata when this folder is opened. These two
# attributes are prohibited by codesign; remove them only from generated output.
xattr -rd com.apple.FinderInfo "$app_dir" 2>/dev/null || true
xattr -rd com.apple.ResourceFork "$app_dir" 2>/dev/null || true
codesign --force --sign - --identifier "$bundle_id" "$app_dir"
codesign --verify --deep --strict "$app_dir"
printf '\nBuilt: %s\n' "$app_dir"
