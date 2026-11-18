import AppKit
import Foundation

/// Where AirPlay Receiver lives in Settings for a given macOS version.
struct ReceiverSettingsDestination: Equatable {
    let url: URL
    /// Human-readable path shown when the deep link can't be opened.
    let manualPath: String
}

enum ReceiverSettings {
    /// macOS 13+ (System Settings): General > AirDrop & Handoff.
    static let modernURL = URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension")!
    /// macOS 12 (System Preferences): Sharing pane, which holds AirPlay Receiver.
    static let montereyURL = URL(string: "x-apple.systempreferences:com.apple.preferences.sharing")!

    static func destination(for version: OperatingSystemVersion) -> ReceiverSettingsDestination {
        if version.majorVersion >= 13 {
            return ReceiverSettingsDestination(
                url: modernURL,
                manualPath: "System Settings → General → AirDrop & Handoff (AirDrop & Continuity on newer macOS) → AirPlay Receiver"
            )
        }
        return ReceiverSettingsDestination(
            url: montereyURL,
            manualPath: "System Preferences → Sharing → AirPlay Receiver"
        )
    }
}

enum SettingsOpenResult: Equatable {
    case opened
    case failed(manualPath: String)
}

/// Opens the AirPlay Receiver settings pane. It only asks the system to show
/// the pane; it never reads or changes the receiver setting itself.
struct SettingsOpener {
    var osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    var open: (URL) -> Bool = { NSWorkspace.shared.open($0) }

    var destination: ReceiverSettingsDestination {
        ReceiverSettings.destination(for: osVersion)
    }

    func openReceiverSettings() -> SettingsOpenResult {
        open(destination.url) ? .opened : .failed(manualPath: destination.manualPath)
    }
}
