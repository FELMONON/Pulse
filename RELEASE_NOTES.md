# Pulse 1.0

Pulse is a minimal macOS Notification Center widget for quick system monitoring.

## Highlights

- Activity-ring widgets for CPU, memory, and disk usage.
- Color-coded battery status.
- Live network upload and download rates.
- Small, medium, and large WidgetKit layouts.
- Menu bar companion with CPU/RAM summary, refresh, settings, and quit actions.
- Launch at Login support so Pulse can keep the widget cache fresh after reboot.
- Settings for refresh interval, network units, and visible widget/menu metrics.
- Signed packaging scripts for local installs, zip/DMG artifacts, checksums, and notarization submission.

## Requirements

- macOS 14.0 Sonoma or later.

## Install

Download either release artifact:

- `Pulse-1.0.dmg`
- `Pulse-1.0.zip`

For the DMG, open it and drag `Pulse.app` to `/Applications`. For the zip, unzip it and move `Pulse.app` to `/Applications`.

After launching Pulse, open Notification Center, choose **Edit Widgets**, search for **Pulse**, and add the preferred widget size.

## Release Assets

Recommended GitHub Release uploads:

- `Pulse-1.0.dmg`
- `Pulse-1.0.zip`
- `Pulse-1.0-SHA256SUMS.txt`
- Any staged screenshot assets from `build/release/screenshots`

## Maintainer Checklist

- Build and sign the app with a Developer ID Application certificate.
- Package with `./scripts/package-release.sh`.
- Notarize with `NOTARIZE=1` using either `NOTARYTOOL_KEYCHAIN_PROFILE` or `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD`.
- Confirm `codesign --verify --deep --strict --verbose=2` passes for the final staged app.
- Confirm the generated SHA-256 file matches uploaded artifacts.
