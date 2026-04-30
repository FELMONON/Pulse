#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Pulse.xcodeproj"
SCHEME="${SCHEME:-MacMonitorApp}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"
INSTALL_PATH="${INSTALL_PATH:-/Applications/Pulse.app}"
TEAM_ID="${DEVELOPMENT_TEAM:-WJX5PBY73S}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Apple Development: felmon.fekadu@icloud.com (WJX5PBY73S)}"

APP_ENTITLEMENTS="$ROOT_DIR/Sources/MacMonitorApp.entitlements"
EXTENSION_ENTITLEMENTS="$ROOT_DIR/Sources/MacMonitorWidgetExtension.entitlements"
BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/MacMonitorApp.app"
BUILT_EXTENSION="$BUILT_APP/Contents/PlugIns/MacMonitorWidgetExtension.appex"

printf 'Using signing identity: %s\n' "$SIGNING_IDENTITY"
if ! security find-identity -v -p codesigning | grep -Fq "$SIGNING_IDENTITY"; then
  printf 'error: signing identity was not found in the keychain.\n' >&2
  printf 'Set SIGNING_IDENTITY to an installed codesigning identity, or install the Apple Development certificate for team %s.\n' "$TEAM_ID" >&2
  exit 1
fi

printf 'Building %s %s without Xcode-managed signing...\n' "$SCHEME" "$CONFIGURATION"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGNING_ALLOWED=NO \
  build

printf 'Signing widget extension...\n'
codesign --force \
  --sign "$SIGNING_IDENTITY" \
  --timestamp=none \
  --entitlements "$EXTENSION_ENTITLEMENTS" \
  "$BUILT_EXTENSION"

printf 'Signing app...\n'
codesign --force \
  --sign "$SIGNING_IDENTITY" \
  --timestamp=none \
  --entitlements "$APP_ENTITLEMENTS" \
  "$BUILT_APP"

printf 'Verifying signed build...\n'
codesign --verify --deep --strict --verbose=2 "$BUILT_APP"

printf 'Quitting existing Pulse instance if it is running...\n'
osascript -e 'tell application id "com.macmonitor.widget" to quit' >/dev/null 2>&1 || true

printf 'Installing to %s...\n' "$INSTALL_PATH"
rsync -a --delete "$BUILT_APP/" "$INSTALL_PATH/"

printf 'Verifying installed app...\n'
codesign --verify --deep --strict --verbose=2 "$INSTALL_PATH"
codesign -d --entitlements :- "$INSTALL_PATH" >/dev/null
codesign -d --entitlements :- "$INSTALL_PATH/Contents/PlugIns/MacMonitorWidgetExtension.appex" >/dev/null

printf 'Launching Pulse...\n'
open -a Pulse

printf 'Done.\n'
