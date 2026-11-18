import XCTest
@testable import ScreenViewer

final class SettingsOpenerTests: XCTestCase {
    private func version(_ major: Int) -> OperatingSystemVersion {
        OperatingSystemVersion(majorVersion: major, minorVersion: 0, patchVersion: 0)
    }

    func testMontereyUsesSharingPane() {
        let d = ReceiverSettings.destination(for: version(12))
        XCTAssertEqual(d.url, ReceiverSettings.montereyURL)
        XCTAssertTrue(d.manualPath.contains("Sharing"))
    }

    func testVenturaAndLaterUseAirDropHandoffPane() {
        for major in [13, 14, 15, 26] {
            let d = ReceiverSettings.destination(for: version(major))
            XCTAssertEqual(d.url, ReceiverSettings.modernURL, "macOS \(major)")
            XCTAssertTrue(d.manualPath.contains("AirDrop & Handoff"))
        }
    }

    func testOpenSuccessOpensExpectedURL() {
        var opened: URL?
        let opener = SettingsOpener(osVersion: version(14), open: { opened = $0; return true })
        XCTAssertEqual(opener.openReceiverSettings(), .opened)
        XCTAssertEqual(opened, ReceiverSettings.modernURL)
    }

    func testOpenFailureReturnsManualPath() {
        let opener = SettingsOpener(osVersion: version(12), open: { _ in false })
        XCTAssertEqual(opener.openReceiverSettings(),
                       .failed(manualPath: "System Preferences → Sharing → AirPlay Receiver"))
    }

    func testURLsUseSystemSettingsScheme() {
        XCTAssertEqual(ReceiverSettings.modernURL.scheme, "x-apple.systempreferences")
        XCTAssertEqual(ReceiverSettings.montereyURL.scheme, "x-apple.systempreferences")
    }
}
