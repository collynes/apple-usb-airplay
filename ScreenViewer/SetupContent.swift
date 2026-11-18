import Foundation

/// User-facing copy, kept in one place so it is easy to review against
/// Apple's current support documentation before each release.
enum SetupContent {
    static let title = "Mirror iPhone to Mac"

    static let intro = "Connect by USB cable to see your iPhone right in this window. Over Wi‑Fi, your Mac's built-in AirPlay Receiver shows the iPhone in its own full-screen view instead, and this app walks you through setting that up."

    static let steps: [String] = [
        "On this Mac, click **Open AirPlay Receiver Settings** and turn on **AirPlay Receiver**.",
        "Make sure Wi‑Fi is on for both iPhone and Mac. Being on the same network and signed in to the same Apple Account helps your Mac show up.",
        "On iPhone, open **Control Center** and tap **Screen Mirroring**.",
        "Choose this Mac from the list. If a code appears on the Mac, enter it on iPhone.",
        "To stop, open Control Center on iPhone, tap **Screen Mirroring**, then **Stop Mirroring**."
    ]

    static let whereTitle = "Where the mirror appears"
    static let whereBody = "With AirPlay, macOS opens the mirrored iPhone itself, usually full screen, not in this window. Apps can't pull that picture in. For an in-window view, use a USB cable."

    static let troubleshooting: [String] = [
        "**Supported devices:** iPhone 7 or later with iOS 14 or later, and a Mac running macOS Monterey 12 or later (iMac Pro, Mac mini 2020 or later, or other Mac models from 2018 or later). Check Apple's current requirements if unsure.",
        "**Receiver on:** AirPlay Receiver is turned on in Settings. If the setting is missing, this Mac may not support AirPlay to Mac.",
        "**Wi‑Fi:** Wi‑Fi is on for both devices, ideally on the same network.",
        "**Who can connect:** \"Allow AirPlay for\" includes your iPhone (Current User, Anyone on the Same Network, or Everyone). Consider Require Password with the wider options.",
        "**Awake and unlocked:** Both devices are awake and unlocked.",
        "**Black or blank picture:** Some apps block mirroring of protected video. That is enforced by the app or system and this helper cannot change it."
    ]
}
