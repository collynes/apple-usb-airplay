import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject private var usb: USBMirrorController
    private let opener: SettingsOpener

    init(usb: USBMirrorController, opener: SettingsOpener = SettingsOpener()) {
        self._usb = ObservedObject(wrappedValue: usb)
        self.opener = opener
    }

    @State private var openFailed = false
    @State private var showTroubleshooting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                USBStatusCard(usb: usb)
                sectionHeading("Wireless with AirPlay")
                settingsSection
                stepsSection
                whereSection
                troubleshootingSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "airplayvideo")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(SetupContent.title)
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
            }
            Text(SetupContent.intro)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: openSettings) {
                Label("Open AirPlay Receiver Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityHint("Opens System Settings so you can turn on AirPlay Receiver. This app can't change the setting for you.")

            if openFailed {
                Label {
                    Text("Couldn't open Settings automatically. Go to \(opener.destination.manualPath) and turn it on.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .accessibilityHidden(true)
                }
                .font(.callout)
                .accessibilityElement(children: .combine)
            } else {
                Text("You'll find it at \(opener.destination.manualPath).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("How to connect")
            ForEach(Array(SetupContent.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1).")
                        .monospacedDigit()
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey(step))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var whereSection: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "rectangle.on.rectangle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(SetupContent.whereTitle).font(.headline)
                Text(SetupContent.whereBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .accessibilityElement(children: .combine)
    }

    private var troubleshootingSection: some View {
        DisclosureGroup(isExpanded: $showTroubleshooting) {
            VStack(alignment: .leading, spacing: 8) {
                Text("If your Mac doesn't appear in Screen Mirroring, check:")
                    .foregroundStyle(.secondary)
                ForEach(SetupContent.troubleshooting, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary).accessibilityHidden(true)
                        Text(LocalizedStringKey(item))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Troubleshooting").font(.headline)
        }
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Actions

    private func openSettings() {
        switch opener.openReceiverSettings() {
        case .opened:
            openFailed = false
        case .failed(let manualPath):
            openFailed = true
            showTroubleshooting = true
            announce("Couldn't open Settings. Go to \(manualPath) and turn on AirPlay Receiver.")
        }
    }

    private func announce(_ message: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(usb: USBMirrorController())
        ContentView(usb: USBMirrorController(), opener: SettingsOpener(open: { _ in false }))
            .previewDisplayName("Open fails")
    }
}
