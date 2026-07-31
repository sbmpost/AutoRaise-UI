#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AutoRaise Dev"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
INSTALL_DIR="${AUTORAISE_DEV_INSTALL_DIR:-/Applications}"
BUILD_PRODUCTS="$INSTALL_DIR/.AutoRaise Dev Build"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
BUILT_APP_BUNDLE="$BUILD_PRODUCTS/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
LOGIN_KEYCHAIN="${AUTORAISE_DEV_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
SIGNING_IDENTITY="${AUTORAISE_DEV_SIGNING_IDENTITY:-}"

cleanup_build_products() {
  rm -rf -- "$BUILD_PRODUCTS"
}
trap cleanup_build_products EXIT

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
elif [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

PODS_CONFIG="$ROOT_DIR/Pods/Target Support Files/Pods-AutoRaise/Pods-AutoRaise.debug.xcconfig"
PODS_MANIFEST="$ROOT_DIR/Pods/Manifest.lock"
if [[ ! -f "$PODS_CONFIG" || ! -f "$PODS_MANIFEST" ]] || ! cmp -s "$ROOT_DIR/Podfile.lock" "$PODS_MANIFEST"; then
  (cd "$ROOT_DIR" && pod install)
fi

SIGNING_IDENTITIES="$(security find-identity -v -p codesigning "$LOGIN_KEYCHAIN")"
if [[ "$SIGNING_IDENTITIES" != *'"Apple Development:'* ]]; then
  echo "error: no valid Apple Development signing identity found in $LOGIN_KEYCHAIN" >&2
  exit 1
fi
SIGNING_COMMON_NAME="$(awk -F '"' '/"Apple Development:/{print $2; exit}' <<< "$SIGNING_IDENTITIES")"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(awk '/"Apple Development:/{print $2; exit}' <<< "$SIGNING_IDENTITIES")"
fi
CERTIFICATE_PEM="$(security find-certificate -c "$SIGNING_COMMON_NAME" -p "$LOGIN_KEYCHAIN")"
CERTIFICATE_SUBJECT="$(openssl x509 -noout -subject -nameopt RFC2253 <<< "$CERTIFICATE_PEM")"
DEVELOPMENT_TEAM="${AUTORAISE_DEV_TEAM_ID:-$(sed -E 's/.*OU=([^,]+).*/\1/' <<< "$CERTIFICATE_SUBJECT")}"
if [[ -z "$DEVELOPMENT_TEAM" ]]; then
  echo "error: could not determine the Apple Development Team ID" >&2
  exit 1
fi

rm -rf -- "$BUILD_PRODUCTS"

xcodebuild \
  -workspace "$ROOT_DIR/AutoRaise.xcworkspace" \
  -scheme AutoRaise \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  CONFIGURATION_BUILD_DIR="$BUILD_PRODUCTS" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  build

/usr/bin/codesign --verify --deep --strict --verbose=4 "$BUILT_APP_BUNDLE"
/usr/bin/ditto "$BUILT_APP_BUNDLE" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=4 "$APP_BUNDLE"
SIGNING_DETAILS="$(/usr/bin/codesign -dvvv -r- "$APP_BUNDLE" 2>&1)"
if [[ "$SIGNING_DETAILS" != *"Authority=Apple Development:"* || "$SIGNING_DETAILS" == *"TeamIdentifier=not set"* ]]; then
  echo "error: $APP_BUNDLE does not have a stable Apple Development signature" >&2
  echo "$SIGNING_DETAILS" >&2
  exit 1
fi
echo "stableLaunchPath=$APP_BUNDLE"
echo "$SIGNING_DETAILS" | grep -E '^(Identifier|Authority|TeamIdentifier)='

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs|--telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
