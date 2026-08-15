#!/bin/zsh

set -euo pipefail

ROOT_DIR=${0:A:h:h}
DIST_DIR="$ROOT_DIR/dist"
SOURCE_APP="$DIST_DIR/Spotlight English.app"
RELEASE_DIR="$DIST_DIR/release"
STAGING_DIR=$(mktemp -d /tmp/spotlight-english-release.XXXXXX)
PACKAGE_APP="$STAGING_DIR/Spotlight English.app"
VOLUME_DIR="$STAGING_DIR/Spotlight English"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")
ZIP_PATH="$RELEASE_DIR/Spotlight-English-v${VERSION}.zip"
DMG_PATH="$RELEASE_DIR/Spotlight-English-v${VERSION}.dmg"

trap 'rm -rf "$STAGING_DIR"' EXIT

if [[ ${1:-} != "--skip-build" ]]; then
    "$ROOT_DIR/scripts/build.sh" --universal
fi

if [[ ! -d "$SOURCE_APP" ]]; then
    print -u2 "Application bundle not found: $SOURCE_APP"
    exit 1
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR" "$VOLUME_DIR"

# Package from /tmp so Finder/File Provider metadata cannot be re-attached
# between code-signing verification and archive creation.
ditto --norsrc "$SOURCE_APP" "$PACKAGE_APP"
xattr -cr "$PACKAGE_APP"
codesign --verify --deep --strict "$PACKAGE_APP"
plutil -lint "$PACKAGE_APP/Contents/Info.plist"
lipo "$PACKAGE_APP/Contents/MacOS/SpotlightEnglish" -verify_arch arm64 x86_64

ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_APP" "$ZIP_PATH"

ditto --norsrc "$PACKAGE_APP" "$VOLUME_DIR/Spotlight English.app"
ln -s /Applications "$VOLUME_DIR/Applications"
hdiutil create \
    -volname "Spotlight English" \
    -srcfolder "$VOLUME_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH"

(
    cd "$RELEASE_DIR"
    shasum -a 256 \
        "${ZIP_PATH:t}" \
        "${DMG_PATH:t}" > SHA256SUMS.txt
)

print "Release artifacts:"
print "  $ZIP_PATH"
print "  $DMG_PATH"
print "  $RELEASE_DIR/SHA256SUMS.txt"
