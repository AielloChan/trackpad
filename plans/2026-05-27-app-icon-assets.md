# App Icon Asset Integration Plan

**Goal:** Apply the transparent-background Trackpad app icon to the iOS and macOS app targets, and show the logo in the default README.

## Tasks

- [x] Add repository README logo asset.
- [x] Add iOS `AppIcon.appiconset` image sizes and metadata.
- [x] Add macOS `AppIcon.appiconset` image sizes and metadata.
- [x] Wire asset catalogs into both Xcode projects.
- [x] Verify iOS and macOS app builds.
- [x] Replace the first black-background icon render with the transparent source provided at `/Users/aiello/Downloads/Image_générée_1-removebg-preview.png`.

## Verification

- `python3 -m json.tool` validates all asset catalog `Contents.json` files.
- `xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -configuration Debug build` succeeded.
- `xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -scheme TrackpadIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded.
