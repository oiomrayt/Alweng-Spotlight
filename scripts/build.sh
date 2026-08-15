#!/bin/zsh

set -euo pipefail

ROOT_DIR=${0:A:h:h}
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Spotlight English.app"
STAGING_DIR=$(mktemp -d /tmp/spotlight-english.XXXXXX)
APP_DIR="$STAGING_DIR/$APP_NAME"
FINAL_APP="$DIST_DIR/$APP_NAME"
MACOS_DIR="$APP_DIR/Contents/MacOS"
UNIVERSAL=false

trap 'rm -rf "$STAGING_DIR"' EXIT

if [[ ${1:-} == "--universal" ]]; then
    UNIVERSAL=true
fi

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR"

if [[ "$UNIVERSAL" == true ]]; then
    for arch in arm64 x86_64; do
        swift build \
            --package-path "$ROOT_DIR" \
            --configuration release \
            --arch "$arch" \
            --scratch-path "$ROOT_DIR/.build/$arch"
    done

    ARM_BINARY=$(swift build --package-path "$ROOT_DIR" --configuration release --arch arm64 --scratch-path "$ROOT_DIR/.build/arm64" --show-bin-path)/SpotlightEnglish
    INTEL_BINARY=$(swift build --package-path "$ROOT_DIR" --configuration release --arch x86_64 --scratch-path "$ROOT_DIR/.build/x86_64" --show-bin-path)/SpotlightEnglish
    lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$MACOS_DIR/SpotlightEnglish"
else
    swift build --package-path "$ROOT_DIR" --configuration release
    BIN_DIR=$(swift build --package-path "$ROOT_DIR" --configuration release --show-bin-path)
    cp "$BIN_DIR/SpotlightEnglish" "$MACOS_DIR/SpotlightEnglish"
fi

cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
xattr -cr "$APP_DIR"
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true

SIGNING_IDENTITY=${CODESIGN_IDENTITY:--}
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
ditto "$APP_DIR" "$FINAL_APP"

# File Provider may immediately re-attach Finder metadata in synchronized
# folders. Retry the cleanup/verification pair to avoid a signing race.
VERIFIED=false
for _ in {1..10}; do
    xattr -d com.apple.FinderInfo "$FINAL_APP" 2>/dev/null || true
    xattr -d 'com.apple.fileprovider.fpfs#P' "$FINAL_APP" 2>/dev/null || true
    if codesign --verify --deep --strict "$FINAL_APP" 2>/dev/null; then
        VERIFIED=true
        break
    fi
    sleep 0.1
done

if [[ "$VERIFIED" != true ]]; then
    codesign --verify --deep --strict "$FINAL_APP"
fi

print "Built: $FINAL_APP"
