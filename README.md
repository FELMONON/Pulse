# Pulse

> A minimal, beautiful macOS System Monitor Widget for Notification Center

## Features

**Activity Ring Design** — Apple Watch-inspired circular progress indicators with distinct colors:

| Metric | Color | Description |
|--------|-------|-------------|
| CPU | 🟢 Green | Processor usage |
| RAM | 🔵 Blue | Memory usage |
| Disk | 🟠 Amber | Storage usage |

**Smart Battery Indicator** — Color-coded status that changes based on level:
- Green (≥50%) — Healthy
- Amber (21-49%) — Moderate
- Red (≤20%) — Low

**Network Monitor** — Real-time upload/download speeds in MB/s

**Three Widget Sizes** — Small, Medium, and Large options for Notification Center

**Menu Bar Companion** — CPU/RAM summary with quick refresh, settings, and quit actions.

**Configurable Background Refresh** — Launch at Login keeps the shared widget cache warm after reboot, with settings for refresh interval, units, and visible metrics.

## Requirements

- macOS 14.0 Sonoma or later
- Xcode 15.0+ (for building from source)
- Apple Developer ID certificate and notary credentials for public releases

## Installation

**Download a Release:**

Download the latest `.dmg` or `.zip` from GitHub Releases, then move `Pulse.app` to `/Applications`. If macOS blocks the first launch, confirm that the downloaded artifact came from the project release page and open it again from Finder.

**Build from Source:**

```bash
git clone https://github.com/felmonon/Pulse.git
cd Pulse
open Pulse.xcodeproj
```

Then press `⌘R` to build and run.

**Scripted Local Build and Install:**

```bash
./scripts/build-install-release.sh
```

The script builds the release app, signs the app and widget extension with the shared app-group entitlement, installs it to `/Applications/Pulse.app`, verifies the signature, and relaunches Pulse. It defaults to team `WJX5PBY73S`; override `SIGNING_IDENTITY`, `DEVELOPMENT_TEAM`, `INSTALL_PATH`, or `LAUNCH_AFTER_INSTALL` if needed.

For Developer ID signing, set a Developer ID Application identity. Hardened runtime and timestamping are enabled automatically for identities that start with `Developer ID Application:`.

```bash
DEVELOPMENT_TEAM="TEAMID1234" \
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID1234)" \
INSTALL_PATH="$PWD/build/release/Pulse.app" \
LAUNCH_AFTER_INSTALL=0 \
./scripts/build-install-release.sh
```

## Release Packaging

Package an already built and signed app into repeatable release artifacts:

```bash
APP_PATH="$PWD/build/release/Pulse.app" ./scripts/package-release.sh
```

Packaging requires a `Developer ID Application` signature by default, because those are the artifacts suitable for a public GitHub Release. For local-only development artifacts, add `REQUIRE_DEVELOPER_ID=0`.

By default this creates:

- `build/release/Pulse-<version>.zip`
- `build/release/Pulse-<version>.dmg`
- `build/release/Pulse-<version>-SHA256SUMS.txt`

Useful options:

```bash
CREATE_DMG=0 APP_PATH="$PWD/build/release/Pulse.app" ./scripts/package-release.sh
REQUIRE_DEVELOPER_ID=0 APP_PATH="/Applications/Pulse.app" ./scripts/package-release.sh
DMG_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID1234)" ./scripts/package-release.sh
```

### Notarization

Notarization requires Apple credentials, so it is opt-in. The script supports a stored notarytool keychain profile:

```bash
xcrun notarytool store-credentials pulse-release \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD"

NOTARIZE=1 \
NOTARYTOOL_KEYCHAIN_PROFILE=pulse-release \
APP_PATH="$PWD/build/release/Pulse.app" \
./scripts/package-release.sh
```

Or direct environment variables:

```bash
NOTARIZE=1 \
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID1234" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
APP_PATH="$PWD/build/release/Pulse.app" \
./scripts/package-release.sh
```

When `NOTARIZE=1`, the script submits and staples the staged app before creating the final zip. If a DMG is enabled, it also submits and staples the DMG unless `NOTARIZE_DMG=0` is set.

### Release Screenshots

The screenshot helper is headless: it does not open the app, drive Finder, or call `screencapture`. Put existing PNG/JPEG/WebP files in `release-assets/screenshots`, then run:

```bash
./scripts/stage-screenshot-assets.sh
```

The staged images and manifest are written to `build/release/screenshots`.

**Add to Notification Center:**

1. Click the date/time in your menu bar
2. Scroll down and click **Edit Widgets**
3. Search for **Pulse**
4. Drag your preferred size to the sidebar

## Tech Stack

- SwiftUI + WidgetKit
- IOKit for system metrics
- AppKit for app detection

## License

MIT

---

*Built with [Claude Code](https://claude.ai/code)*
