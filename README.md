# iPhone Screen Viewer

An iPhone-shaped macOS app for seeing your iPhone on your Mac.

- **USB cable:** the iPhone's live screen appears inside the phone window, the same way QuickTime shows a cabled iPhone. Needs camera permission once. Sound stays on the iPhone (and its headphones) unless you click the speaker button in the status bar to play it on the Mac.
- **Wi‑Fi (AirPlay):** macOS shows the mirror in its own full-screen view; apps can't pull that picture in. The app guides setup and opens the AirPlay Receiver settings. See `SPEC.md` for the full specification.

## Project layout

```
ScreenViewer.xcodeproj         Xcode project (app + unit tests, shared scheme)
ScreenViewer/
  ScreenViewerApp.swift        App entry, single window, quits on last window close
  ContentView.swift            Guide screen: USB card, AirPlay steps, settings button, troubleshooting
  PhoneChrome.swift            Phone-shaped frameless window, close/minimize buttons, dragging
  USBMirror.swift              USB live view: CoreMediaIO opt-in, device discovery, AVCaptureSession
  SettingsOpener.swift         Settings deep link per macOS version + open-result handling
  SetupContent.swift           All user-facing copy in one place for release review
  Assets.xcassets              AppIcon slots (add artwork before release)
  ScreenViewer.entitlements    App Sandbox + camera (for the USB view only)
ScreenViewerTests/
  SettingsOpenerTests.swift    Unit tests for URL choice and failure fallback
```

`ScreenViewer.swift` in the folder root is the original prototype. It is not part of the project and can be removed.

## Install on another Mac

```sh
./scripts/make-installer.sh
```

This builds a Release app for Apple silicon and Intel and creates `dist/iPhoneScreenViewer-<version>.dmg`. Copy the DMG to the other Mac, open it and drag ScreenViewer to Applications. Without a Developer ID the first launch needs System Settings > Privacy & Security > Open Anyway (instructions are inside the DMG). With a paid developer account, set `DEVELOPER_ID`, `DEVELOPMENT_TEAM` and `NOTARY_PROFILE` (see the script header) for a signed, notarized DMG.

## Build and run

Requires full Xcode (14 or later) on macOS.

- **Xcode:** open `ScreenViewer.xcodeproj`, pick the *ScreenViewer* scheme, press Run.
- **Terminal:**
  ```sh
  xcodebuild -project ScreenViewer.xcodeproj -scheme ScreenViewer -configuration Release build
  xcodebuild -project ScreenViewer.xcodeproj -scheme ScreenViewer test
  ```

Deployment target is macOS 12. The project signs ad hoc ("Sign to Run Locally"). For distribution, set your Team, a Developer ID identity and your own bundle identifier (currently `com.example.iphonescreenviewer`).

## How it maps to the spec

| Spec | Implementation |
|---|---|
| F1 main screen | Title, intro, numbered steps, resizable scrolling layout (min 380 x 360) |
| F2 open settings | `SettingsOpener`: macOS 13+ opens AirDrop & Handoff, macOS 12 opens Sharing. If `NSWorkspace.open` fails, the app shows the manual path, announces it to VoiceOver and expands troubleshooting |
| F3 instructions | Steps plus a "Where the mirror appears" note stating macOS renders the session |
| F4 troubleshooting | Expandable checklist: devices/OS, receiver on, Wi-Fi, "Allow AirPlay for", awake/unlocked, protected content |
| F5 accessibility | Decorative icons hidden, headings marked, steps read as single elements, Return triggers the primary button, VoiceOver hint explains the app can't toggle the setting |
| F6 USB live view | `USBMirrorController` + `CapturePreview`, full-bleed in the phone screen |
| F7 phone window | `PhoneChrome.swift` |
| Privacy | No network, storage, telemetry or third-party code. Camera used only to display a cabled iPhone, nothing recorded |

## Using it

**USB:** click **Use USB Cable**, allow camera access, plug in the iPhone, unlock it and tap Trust. Unplug to return to the guide. The window turns to landscape by itself when the iPhone does (videos, games), or press the rotate button / ⌘R.

**AirPlay:**

1. Click **Open AirPlay Receiver Settings** and turn on **AirPlay Receiver**.
2. On iPhone, open Control Center, tap **Screen Mirroring**, choose this Mac.
3. macOS shows the mirror in its own session, outside this window.

Requirements (verify against Apple's current docs before each release): iPhone 7 or later with iOS 14+, and macOS Monterey 12+ on iMac Pro, Mac mini (2020 or later) or other Macs from 2018 or later.

## Still to do (spec §11/§12)

- Build and test on real hardware, oldest (12) and current macOS.
- Confirm the settings deep links on each macOS version you support.
- VoiceOver, keyboard, larger-text and resize pass.
- App icon artwork, signing, notarization.
