#!/bin/bash
#
# Package the signed Universal app as ZIP and DMG, then write SHA-256 files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:?usage: package-no-sandbox.sh <signed .app> [version]}"
VERSION="${2:-1.0.4}"
DIST="$REPO_ROOT/dist"
STEM="AppDrop-NoSandbox-$VERSION-macOS-universal"
ZIP_PATH="$DIST/$STEM.zip"
DMG_PATH="$DIST/$STEM.dmg"
STAGING="$(mktemp -d /private/tmp/AppDrop-NoSandbox-package.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT

mkdir -p "$DIST"
if [ -e "$ZIP_PATH" ]; then
    mv "$ZIP_PATH" "$ZIP_PATH.previous-$(date +%s)"
fi
if [ -e "$DMG_PATH" ]; then
    mv "$DMG_PATH" "$DMG_PATH.previous-$(date +%s)"
fi

ditto --norsrc --noextattr -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

mkdir -p "$STAGING/AppDrop No Sandbox"
ditto --norsrc --noextattr "$APP_PATH" "$STAGING/AppDrop No Sandbox/AppDrop No Sandbox.app"
ln -s /Applications "$STAGING/AppDrop No Sandbox/Applications"
hdiutil create \
    -volname "AppDrop No Sandbox" \
    -srcfolder "$STAGING/AppDrop No Sandbox" \
    -ov -format UDZO \
    "$DMG_PATH"

(
    cd "$DIST"
    shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$ZIP_PATH").sha256"
    shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256"
)

echo "$ZIP_PATH"
echo "$DMG_PATH"
