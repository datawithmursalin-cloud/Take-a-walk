#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
app_dir="$HOME/Applications/Take a Walk.app"
if [ -d "$app_dir" ] && pgrep -fx "$app_dir/Contents/MacOS/TakeAWalk" >/dev/null; then
    open "$app_dir"
    exit 0
fi
"$project_dir/scripts/build.sh"
open "$app_dir"
