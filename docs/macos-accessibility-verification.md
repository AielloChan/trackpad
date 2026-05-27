# macOS Accessibility Verification

The host cannot inject pointer, click, or scroll events until macOS grants Accessibility permission to the running binary or app.

## Command-Line Host

From the repository root:

```bash
cd apps/macos/TrackpadHost
swift run TrackpadHost request-permission
swift run TrackpadHost status
```

Expected after authorization:

```text
Accessibility trusted: true
```

Then verify pointer movement:

```bash
swift run TrackpadHost move-test
```

Expected: the pointer moves horizontally by about 100 points.

Click and scroll checks should only be run in a safe empty area:

```bash
swift run TrackpadHost left-click-test
swift run TrackpadHost right-click-test
swift run TrackpadHost scroll-test
```

## Native macOS App

Open:

```text
apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj
```

Run the `TrackpadHostApp` scheme, click `Request Permission`, grant Accessibility permission in System Settings, then click `Refresh`.

Expected: the app displays `Accessibility permission granted`.

## Current Status

The command-line host has been granted Accessibility permission and pointer movement has been verified by reading pointer coordinates before and after `move-test`.

Observed:

```text
Accessibility trusted: true
before 856.046875 -416.4609375
after 1245.125 -301.30078125
```

Do not mark click and scroll behavior verified until those actions have been observed in a safe empty UI area.
