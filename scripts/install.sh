#!/bin/zsh

set -euo pipefail

ROOT_DIR=${0:A:h:h}
SOURCE_APP="$ROOT_DIR/dist/Spotlight English.app"
DESTINATION_APP="/Applications/Spotlight English.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/io.github.oiomrayt.SpotlightEnglish.plist"
SERVICE="gui/$UID/io.github.oiomrayt.SpotlightEnglish"

if [[ ! -d "$SOURCE_APP" ]]; then
    "$ROOT_DIR/scripts/build.sh"
fi

launchctl bootout "$SERVICE" 2>/dev/null || true
pkill -x SpotlightEnglish 2>/dev/null || true
for _ in {1..20}; do
    pgrep -x SpotlightEnglish >/dev/null || break
    sleep 0.1
done

if [[ -w /Applications ]]; then
    rm -rf "$DESTINATION_APP"
    ditto "$SOURCE_APP" "$DESTINATION_APP"
else
    sudo rm -rf "$DESTINATION_APP"
    sudo ditto "$SOURCE_APP" "$DESTINATION_APP"
fi

VERIFIED=false
for _ in {1..10}; do
    xattr -d com.apple.FinderInfo "$DESTINATION_APP" 2>/dev/null || true
    xattr -d 'com.apple.fileprovider.fpfs#P' "$DESTINATION_APP" 2>/dev/null || true
    if codesign --verify --deep --strict "$DESTINATION_APP" 2>/dev/null; then
        VERIFIED=true
        break
    fi
    sleep 0.1
done

if [[ "$VERIFIED" != true ]]; then
    codesign --verify --deep --strict "$DESTINATION_APP"
fi

mkdir -p "$HOME/Library/LaunchAgents"
plutil -create xml1 "$LAUNCH_AGENT"
plutil -insert Label -string io.github.oiomrayt.SpotlightEnglish "$LAUNCH_AGENT"
plutil -insert ProgramArguments -json "[\"/usr/bin/open\",\"$DESTINATION_APP\"]" "$LAUNCH_AGENT"
plutil -insert RunAtLoad -bool YES "$LAUNCH_AGENT"

launchctl bootstrap "gui/$UID" "$LAUNCH_AGENT"
open "$DESTINATION_APP"

print "Installed: $DESTINATION_APP"
print "Allow Spotlight English in System Settings → Privacy & Security → Accessibility."
