#!/bin/zsh

set -euo pipefail

DESTINATION_APP="/Applications/Spotlight English.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/io.github.oiomrayt.SpotlightEnglish.plist"
SERVICE="gui/$UID/io.github.oiomrayt.SpotlightEnglish"

launchctl bootout "$SERVICE" 2>/dev/null || true
pkill -x SpotlightEnglish 2>/dev/null || true
for _ in {1..20}; do
    pgrep -x SpotlightEnglish >/dev/null || break
    sleep 0.1
done

if [[ -d "$DESTINATION_APP" ]]; then
    if [[ -w /Applications ]]; then
        rm -rf "$DESTINATION_APP"
    else
        sudo rm -rf "$DESTINATION_APP"
    fi
fi

rm -f "$LAUNCH_AGENT"

print "Spotlight English was removed."
