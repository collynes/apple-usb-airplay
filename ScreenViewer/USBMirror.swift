import AppKit
import AVFoundation
import CoreMediaIO
import SwiftUI

/// Shows a USB-connected iPhone's screen using the same public mechanism as
/// QuickTime's "New Movie Recording": once screen-capture devices are allowed,
/// the iPhone appears as an external muxed (video + audio) capture device.
final class USBMirrorController: ObservableObject {
    enum State: Equatable {
        case idle
        case needsPermission
        case denied
        case waiting
        case live(name: String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    let session: AVCaptureSession
    /// Video goes only to this layer. Audio is connected separately, and only when asked,
    /// so the iPhone keeps its own audio route (AirPods/EarPods) by default.
    let previewLayer: AVCaptureVideoPreviewLayer

    /// Play the iPhone's sound on the Mac. Off by default: when on, iOS moves its
    /// audio output to the Mac, which disconnects Bluetooth headphones on the phone.
    @Published var playSoundOnMac: Bool = UserDefaults.standard.bool(forKey: "playSoundOnMac") {
        didSet {
            UserDefaults.standard.set(playSoundOnMac, forKey: "playSoundOnMac")
            if let device = currentDevice { connect(device) }
        }
    }

    /// True when the iPhone is sending a landscape picture (it was rotated).
    @Published private(set) var videoIsLandscape = false

    private let sessionQueue = DispatchQueue(label: "ScreenViewer.usb-session")
    private let frameQueue = DispatchQueue(label: "ScreenViewer.usb-frames")
    private let orientationWatcher = FrameOrientationWatcher()
    private var observers: [NSObjectProtocol] = []
    private var currentDevice: AVCaptureDevice?
    private var currentDeviceID: String? { currentDevice?.uniqueID }
    private var began = false

    init() {
        let session = AVCaptureSession()
        self.session = session
        previewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        previewLayer.videoGravity = .resizeAspect
        orientationWatcher.onChange = { [weak self] isLandscape in
            DispatchQueue.main.async { self?.videoIsLandscape = isLandscape }
        }
    }

    var isLive: Bool {
        if case .live = state { return true }
        return false
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Call on launch. Starts automatically only if camera access was already granted.
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: begin()
        case .notDetermined: state = .needsPermission
        default: state = .denied
        }
    }

    /// User tapped "Use USB Cable".
    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted { self.begin() } else { self.state = .denied }
            }
        }
    }

    // MARK: Discovery

    private func begin() {
        guard !began else { return }
        began = true
        Self.allowScreenCaptureDevices()
        state = .waiting

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })
        observers.append(center.addObserver(forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main) { [weak self] note in
            guard let self = self, let device = note.object as? AVCaptureDevice,
                  device.uniqueID == self.currentDeviceID else { return }
            self.disconnect()
        })
        observers.append(center.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: .main) { [weak self] note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error
            self?.teardown(then: .failed(error?.localizedDescription ?? "The connection to iPhone stopped."))
        })

        refresh()
        // The iPhone shows up a moment after screen-capture devices are allowed.
        for delay in [1.0, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.refresh() }
        }
    }

    private func refresh() {
        guard currentDeviceID == nil, let device = Self.findPhone() else { return }
        connect(device)
    }

    private static func findPhone() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            types = [.external]
        } else {
            types = [.externalUnknown]
        }
        return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .muxed, position: .unspecified)
            .devices.first
    }

    /// Opt this process in to seeing iOS screens as capture devices.
    private static func allowScreenCaptureDevices() {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var allow: UInt32 = 1
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &allow
        )
    }

    // MARK: Session

    private func connect(_ device: AVCaptureDevice) {
        currentDevice = device
        let name = device.localizedName
        let withSound = playSoundOnMac
        let layer = previewLayer
        let watcher = orientationWatcher
        let frameQueue = frameQueue
        watcher.reset()
        sessionQueue.async { [session] in
            session.stopRunning()
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            session.outputs.forEach(session.removeOutput)
            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else { throw CocoaError(.featureUnsupported) }
                // Wire ports by hand so the audio stream is only used when asked for.
                session.addInputWithNoConnections(input)

                guard let videoPort = input.ports.first(where: { $0.mediaType == .video }) ?? input.ports.first else {
                    throw CocoaError(.featureUnsupported)
                }
                let video = AVCaptureConnection(inputPort: videoPort, videoPreviewLayer: layer)
                guard session.canAddConnection(video) else { throw CocoaError(.featureUnsupported) }
                session.addConnection(video)

                // Watch frame dimensions to notice when the iPhone rotates.
                let frames = AVCaptureVideoDataOutput()
                frames.alwaysDiscardsLateVideoFrames = true
                frames.setSampleBufferDelegate(watcher, queue: frameQueue)
                session.addOutputWithNoConnections(frames)
                let frameConnection = AVCaptureConnection(inputPorts: [videoPort], output: frames)
                if session.canAddConnection(frameConnection) { session.addConnection(frameConnection) }

                if withSound, let audioPort = input.ports.first(where: { $0.mediaType == .audio }) {
                    let speaker = AVCaptureAudioPreviewOutput()
                    speaker.volume = 1
                    session.addOutputWithNoConnections(speaker)
                    let audio = AVCaptureConnection(inputPorts: [audioPort], output: speaker)
                    if session.canAddConnection(audio) { session.addConnection(audio) }
                }

                session.commitConfiguration()
                session.startRunning()
                DispatchQueue.main.async { self.state = .live(name: name) }
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    self.currentDevice = nil
                    self.state = .failed("Couldn't connect to \(name): \(error.localizedDescription)")
                }
            }
        }
    }

    private func disconnect() {
        teardown(then: .waiting)
    }

    private func teardown(then next: State) {
        currentDevice = nil
        state = next
        sessionQueue.async { [session] in
            session.stopRunning()
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            session.outputs.forEach(session.removeOutput)
            session.commitConfiguration()
        }
    }
}

// MARK: - Orientation

/// Reads only the size of incoming frames and reports portrait/landscape changes.
final class FrameOrientationWatcher: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onChange: ((Bool) -> Void)?
    private var last: Bool?
    private let lock = NSLock()

    func reset() {
        lock.lock(); last = nil; lock.unlock()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let dims = CMVideoFormatDescriptionGetDimensions(format)
        guard dims.width > 0, dims.height > 0 else { return }
        let isLandscape = dims.width > dims.height
        lock.lock()
        let changed = isLandscape != last
        last = isLandscape
        lock.unlock()
        if changed { onChange?(isLandscape) }
    }
}

// MARK: - Live view

/// Fills its frame with the live iPhone screen. Dragging it moves the window.
struct CapturePreview: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> PreviewView {
        PreviewView(previewLayer: previewLayer)
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        let previewLayer: AVCaptureVideoPreviewLayer

        init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            layer = CALayer()
            wantsLayer = true
            layer?.backgroundColor = NSColor.black.cgColor
            previewLayer.removeFromSuperlayer()
            layer?.addSublayer(previewLayer)
            setAccessibilityElement(true)
            setAccessibilityRole(.image)
            setAccessibilityLabel("Live iPhone screen")
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            CATransaction.commit()
        }

        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}

// MARK: - Guide card

/// Status card shown in the guide while not live.
struct USBStatusCard: View {
    @ObservedObject var usb: USBMirrorController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("See it in this window", systemImage: "cable.connector")
                .font(.headline)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        )
    }

    @ViewBuilder private var content: some View {
        switch usb.state {
        case .idle, .needsPermission:
            Text("Connect your iPhone with a USB cable and its screen appears right here. The Mac asks for camera access the first time, because that's how macOS shares a cabled iPhone's screen.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Use USB Cable") { usb.requestAccess() }
                .accessibilityHint("Asks for camera access, then shows a connected iPhone's screen in this window.")
        case .waiting:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Plug in your iPhone, unlock it, and tap **Trust** if it asks.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        case .denied:
            Text("Camera access is off for this app, so it can't show a cabled iPhone. Turn it on in Privacy & Security → Camera, then reopen the app.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Camera Privacy Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
        case .failed(let message):
            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Unplug the cable and plug it back in to try again.")
                .font(.callout)
        case .live:
            EmptyView()
        }
    }
}

// MARK: - Sound toggle

/// Status-bar button shown while live: play the iPhone's sound on the Mac or keep it on the phone.
struct SoundToggle: View {
    @ObservedObject var usb: USBMirrorController

    var body: some View {
        Button {
            usb.playSoundOnMac.toggle()
        } label: {
            Image(systemName: usb.playSoundOnMac ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 26, height: 22)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(usb.playSoundOnMac ? "Sound plays on this Mac. Click to keep it on iPhone." : "Sound stays on iPhone. Click to play it on this Mac.")
        .accessibilityLabel(usb.playSoundOnMac ? "Sound on Mac" : "Sound on iPhone")
        .accessibilityHint("Switches where iPhone audio plays. Playing on Mac disconnects Bluetooth headphones from the iPhone.")
    }
}
