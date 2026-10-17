#!/bin/bash
#
# Re-sign the Release app outside Xcode so the distributable contains no
# provisioning profile and no sandbox/App Group entitlements.
#
# Usage:
#   Scripts/make-signed-build.sh <source .app> <output .app> [signing identity]

set -euo pipefail

SOURCE_APP="${1:?usage: make-signed-build.sh <source .app> <output .app> [identity]}"
OUTPUT_APP="${2:?usage: make-signed-build.sh <source .app> <output .app> [identity]}"
IDENTITY="${3:-${SIGNING_IDENTITY:-}}"
if [ -z "$IDENTITY" ]; then
    IDENTITY="$(security find-identity -v -p codesigning \
        | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' \
        | head -1)"
fi
if [ -z "$IDENTITY" ]; then
    echo "error: no Apple Development signing identity was found" >&2
    exit 1
fi
STAGING="$(mktemp -d /private/tmp/AppDrop-NoSandbox-sign.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
STAGED_APP="$STAGING/AppDrop No Sandbox.app"
HELPER_APP="$STAGED_APP/Contents/Library/LoginItems/AppDropHelper.app"

ditto --norsrc --noextattr "$SOURCE_APP" "$STAGED_APP"
xattr -cr "$STAGED_APP" || true
find "$STAGED_APP" -name "embedded.provisionprofile" -delete

codesign --force --sign "$IDENTITY" --timestamp=none "$HELPER_APP"
codesign --force --sign "$IDENTITY" --timestamp=none "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

if find "$STAGED_APP" -name "embedded.provisionprofile" | grep -q .; then
    echo "error: a provisioning profile is still embedded" >&2
    exit 1
fi

if codesign -d --entitlements :- "$STAGED_APP" 2>&1 | grep -q "com.apple.security.app-sandbox"; then
    echo "error: app-sandbox entitlement is still present" >&2
    exit 1
fi

if codesign -d --entitlements :- "$HELPER_APP" 2>&1 | grep -q "com.apple.security.app-sandbox"; then
    echo "error: helper app-sandbox entitlement is still present" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_APP")"
if [ -e "$OUTPUT_APP" ]; then
    mv "$OUTPUT_APP" "$OUTPUT_APP.previous-$(date +%s)"
fi
ditto --norsrc --noextattr "$STAGED_APP" "$OUTPUT_APP"
xattr -cr "$OUTPUT_APP" || true
codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP"
lipo -info "$OUTPUT_APP/Contents/MacOS/AppDrop No Sandbox"

echo "signed build written to: $OUTPUT_APP"
