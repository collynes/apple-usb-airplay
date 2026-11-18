import SwiftUI
import AppKit

@main
struct ScreenViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("iPhone Screen Viewer") {
            PhoneWindowRoot()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Single-window utility: no "New Window" item.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
