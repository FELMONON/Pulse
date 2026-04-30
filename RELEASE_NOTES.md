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
- Developer ID release packaging for zip artifacts, optional DMG artifacts, checksums, and notarization submission.

## Requirements

- macOS 14.0 Sonoma or later.

## Signing Status

The v1.0.0 zip contains a `Developer ID Application` signed, hardened-runtime-enabled, notarized, and stapled `Pulse.app` for team `549A496SHU`. The release packaging script enforces Developer ID app signing by default. If artifacts are produced with `REQUIRE_DEVELOPER_ID=0`, treat them as local development builds, not public notarized releases.

## Install

Download the release zip:

- `Pulse-1.0.zip`

Unzip it and move `Pulse.app` to `/Applications`. If a DMG is attached in a later release, open it and drag `Pulse.app` to `/Applications`.

After launching Pulse, open Notification Center, choose **Edit Widgets**, search for **Pulse**, and add the preferred widget size.

## Release Assets

Recommended GitHub Release uploads:

- `Pulse-1.0.zip`
- `Pulse-1.0-SHA256SUMS.txt`
- Any staged screenshot assets from `build/release/screenshots`

Upload `Pulse-1.0.dmg` only when the disk image has also been code-signed with `DMG_SIGNING_IDENTITY`.

## Maintainer Checklist

- Build and sign the app with a Developer ID Application certificate.
- Package with `./scripts/package-release.sh`.
- Notarize with `NOTARIZE=1` using either `NOTARYTOOL_KEYCHAIN_PROFILE` or `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD`.
- Confirm `codesign --verify --deep --strict --verbose=2` passes for the final staged app.
- Confirm `spctl --assess --type execute --verbose=4` accepts the app as `Notarized Developer ID`.
- For DMG releases, confirm `spctl --assess --type open --context context:primary-signature --verbose=4` accepts the disk image.
- Confirm the generated SHA-256 file matches uploaded artifacts.
