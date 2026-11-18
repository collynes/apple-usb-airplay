# iPhone Screen Viewer — Project Specification

## 1. Purpose

Provide a small native macOS companion, shaped like an iPhone, for viewing an iPhone screen on a Mac. Over a USB cable the app shows the iPhone's live screen inside its own window, using the same public capture path as QuickTime. Over Wi‑Fi, macOS is the AirPlay receiver and displays the mirror itself; the application guides that setup and opens the relevant System Settings pane.

## 2. Product boundary

The app is not an AirPlay receiver or an iPhone control surface. Apple does not expose a public API for an ordinary Mac app to join, capture, or embed the macOS system AirPlay mirroring session, so wireless mirroring always appears in the macOS-managed view and the app must not claim otherwise. The in-window view is available only for a USB-connected iPhone, via CoreMediaIO screen-capture devices and AVFoundation (public APIs, camera permission).

### Goals

- Show a USB-connected iPhone's live screen (video and audio) inside the phone-shaped window.
- Explain the supported connection steps clearly.
- Open AirPlay Receiver settings from the app.
- Present accurate compatibility and connection guidance.
- Remain local, lightweight, and usable without an account or network service.

### Non-goals

- Implementing an AirPlay receiver or private AirPlay protocol.
- Capturing or recording the system-rendered AirPlay mirror.
- Recording or saving the USB view (display only).
- Remote control, touch injection, or access to iPhone files/apps.
- Circumventing pairing, DRM, platform restrictions, or regional feature availability.
- Replacing Apple's iPhone Mirroring feature.

## 3. Users and use cases

Primary user: a Mac owner who wants to mirror an iPhone screen using Apple's supported AirPlay to Mac capability.

1. User opens the helper and learns where the mirror will appear.
2. User opens AirPlay Receiver settings and enables the receiver.
3. User opens iPhone Control Center, chooses Screen Mirroring, and selects the Mac.
4. User sees the session rendered by macOS and returns to the helper only if setup guidance is needed.

## 4. Platform and compatibility

- Native macOS SwiftUI application.
- Minimum OS target: macOS 12 (Monterey), subject to Xcode SDK availability and validation.
- AirPlay to Mac requires a supported Mac model and compatible iPhone/iOS version. Apple documents iPhone 7 or later with iOS 14 or later, and macOS Monterey 12 or later on iMac Pro, Mac mini (2020 or later), and other Mac models introduced in 2018 or later. Verify current requirements before release.
- Wi‑Fi must be enabled on both devices. Same Wi‑Fi network and same Apple Account are recommended; receiver permissions may affect discoverability.
- EU availability of iPhone Mirroring does not determine AirPlay to Mac availability; this application only guides AirPlay.

## 5. Functional requirements

### F1 — Main screen

Show a clear title, a short explanation that macOS displays the mirror, and numbered or concise setup steps. Use native system typography and a compact, resizable layout.

### F2 — Open Receiver Settings

Provide a button that opens the macOS AirDrop & Handoff / AirDrop & Continuity settings pane. Use the System Settings URL scheme when supported. If opening fails, show a useful fallback instruction to navigate there manually. Do not imply that the app can toggle the system receiver setting.

### F3 — Connection instructions

Explain that the user must enable AirPlay Receiver on the Mac, then use Control Center → Screen Mirroring on iPhone and select the Mac. Explain that the mirror appears as a macOS-managed session, outside the helper window.

### F4 — Troubleshooting

Provide concise checks: supported Mac/iPhone and OS versions, receiver enabled, Wi‑Fi enabled, same network, receiver access policy, and both devices awake/unlocked as required by the OS. Do not make unsupported claims about credentials or regional restrictions.

### F6 — USB live view

When the user opts in ("Use USB Cable"), request camera access, allow screen-capture devices for the process, and show the first external muxed capture device (the iPhone) full-bleed in the phone screen. Connect video only by default so the iPhone keeps its audio route (e.g. Bluetooth headphones); a status-bar speaker toggle plays iPhone audio on the Mac instead, remembered between launches. Return to the guide when the device disconnects. Show clear states for permission needed, denied (with link to Camera privacy settings), waiting for device (unlock and Trust), and failure.

### F7 — Phone-shaped window

Frameless iPhone-style window with custom close and minimize controls in the status bar, draggable, resizable at the phone's aspect ratio. ⌘W and ⌘M keep working. Portrait and landscape: the window rotates automatically when the live iPhone picture turns landscape, and a status-bar rotate button (⌘R) switches manually; rotation keeps the window's centre and scale and stays on screen.

### F5 — Accessibility

All actions must be available to VoiceOver and keyboard users. Provide meaningful button labels, sufficient contrast, scalable text, and logical focus order. Decorative imagery must be hidden from accessibility when appropriate.

## 6. User interface

Single-window utility screen:

- AirPlay symbol or equivalent decorative system icon.
- Heading: “Mirror iPhone to Mac”.
- One-paragraph explanation of macOS-managed mirroring.
- Primary action: “Open AirPlay Receiver Settings”.
- Setup steps and a short “Where the mirror appears” note.
- Optional expandable troubleshooting section.

Window should remain useful at smaller sizes, support standard macOS window controls, and avoid presenting a fake video player or empty preview panel.

## 7. Technical design

- SwiftUI app lifecycle with a small view hierarchy.
- Use `NSWorkspace.shared.open(_:)` to request opening the System Settings destination.
- Keep settings URL construction and open-result handling in a small helper so the action can be tested and updated independently.
- No server, database, account system, analytics, telemetry, local networking, or Bonjour browsing. Media capture is limited to displaying a USB-connected iPhone (F6); nothing is recorded or stored.
- No third-party dependencies.
- App Sandbox and hardened runtime may be enabled with only the capabilities required by the chosen distribution method; the only entitlement is camera access (`com.apple.security.device.camera`) for F6, with an `NSCameraUsageDescription`.
- Set an app name, bundle identifier, deployment target, and standard macOS icon in the Xcode project.

## 8. Privacy and security

- No collection, storage, or transmission of user data.
- Camera permission is used only to display a USB-connected iPhone, and only after the user opts in. No screen recording, microphone, contacts, photos, or local network access.
- The app only opens a user-requested System Settings page.
- Avoid custom pairing prompts or requests for Apple Account credentials.
- Keep claims and UI explicit that the OS handles the AirPlay session.

## 9. Error and edge-case behavior

- If Settings cannot be opened, keep the app functional and display the manual navigation path.
- If the user's Mac is unsupported or lacks the AirPlay Receiver setting, state that availability depends on Apple's hardware/OS requirements; do not offer a bypass.
- If the iPhone does not list the Mac, show the troubleshooting checklist and advise checking receiver permissions and network conditions.
- If a protected app produces a blank/blocked image, explain that content protection is enforced by the source app/system; do not attempt capture or circumvention.

## 10. Acceptance criteria

- Builds as a native macOS app from an Xcode project.
- Launches to the helper screen without requiring network access.
- Settings button opens the correct System Settings pane on supported macOS versions or reports a clear fallback.
- Instructions accurately direct the user to enable AirPlay Receiver and start Screen Mirroring from iPhone Control Center.
- UI does not represent the helper window as the video receiver and makes clear that macOS renders the session.
- No private APIs, custom AirPlay protocol implementation, security bypasses, permissions unrelated to app behavior, or third-party services.
- VoiceOver identifies the primary action and keyboard navigation reaches it.

## 11. Validation plan

- Build and launch on the oldest supported macOS version and a current macOS version.
- Verify the settings deep link; verify manual fallback when it cannot open.
- Follow the documented AirPlay flow with a compatible iPhone/Mac pair and confirm macOS owns the rendered session.
- Check behavior when AirPlay Receiver is disabled and when the Mac is not discoverable.
- Inspect signing, entitlements, and privacy declarations; confirm no unnecessary permissions or network activity.
- Verify VoiceOver labels, keyboard navigation, window resizing, and larger text.

## 12. Release and documentation

`scripts/make-installer.sh` produces a universal drag-to-Applications DMG, optionally Developer ID signed and notarized. Ship as a signed macOS app bundle through an appropriate distribution route. Include supported hardware/OS requirements, setup instructions, limitations, and troubleshooting. Update these details against Apple's current support documentation before each release.

## 13. Current status

Implemented as an Xcode project (`ScreenViewer.xcodeproj`): phone-shaped window (F7), USB live view (F6), AirPlay guide with settings deep link and fallback (F1 to F4), accessibility labels (F5), and unit tests for the settings helper. Builds and tests pass on the developer's Mac. Still to do: hardware validation of F6 across macOS versions, accessibility pass, app icon, signing and notarization.
