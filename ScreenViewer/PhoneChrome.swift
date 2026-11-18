import SwiftUI
import AppKit

// MARK: - Metrics

enum PhoneMetrics {
    /// Portrait window content size: the phone body plus room for the side keys.
    static let portraitSize = CGSize(width: 396, height: 800)
    static let landscapeSize = CGSize(width: portraitSize.height, height: portraitSize.width)
    static let sideKeyInset: CGFloat = 3
    static let bezel: CGFloat = 13
    static let outerRadius: CGFloat = 62
    static var screenRadius: CGFloat { outerRadius - bezel }
    /// Smallest allowed short side of the window.
    static let minShortSide: CGFloat = 330

    static func size(landscape: Bool) -> CGSize { landscape ? landscapeSize : portraitSize }

    static func minSize(landscape: Bool) -> CGSize {
        let long = minShortSide * portraitSize.height / portraitSize.width
        return landscape ? CGSize(width: long, height: minShortSide) : CGSize(width: minShortSide, height: long)
    }
}

// MARK: - Root

/// Hosts the helper UI inside a phone-shaped, frameless window.
struct PhoneWindowRoot: View {
    @State private var window: NSWindow?
    @State private var landscape = false
    @StateObject private var usb = USBMirrorController()

    var body: some View {
        PhoneFrame(window: window, landscape: landscape, fullBleed: usb.isLive, accessory: AnyView(accessory)) {
            if usb.isLive {
                CapturePreview(previewLayer: usb.previewLayer)
            } else {
                ContentView(usb: usb)
            }
        }
        // The window itself enforces size and aspect ratio; keep SwiftUI out of the way.
        .frame(minWidth: 200, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
        .background(PhoneWindowConfigurator { found in
            DispatchQueue.main.async { window = found }
        })
        .onAppear { usb.start() }
        // Follow the iPhone when it rotates (only while its screen is shown).
        .onChange(of: usb.videoIsLandscape) { isLandscape in
            if usb.isLive { landscape = isLandscape }
        }
        .onChange(of: usb.isLive) { live in
            if live { landscape = usb.videoIsLandscape }
        }
        .onChange(of: landscape) { isLandscape in
            if let window = window { PhoneWindowConfigurator.rotate(window, landscape: isLandscape) }
        }
    }

    private var accessory: some View {
        HStack(spacing: 6) {
            RotateButton(landscape: $landscape)
            if usb.isLive { SoundToggle(usb: usb) }
        }
    }
}

// MARK: - Phone body

struct PhoneFrame<Content: View>: View {
    let window: NSWindow?
    let landscape: Bool
    /// Live iPhone screen: content fills the whole screen, controls float on top.
    let fullBleed: Bool
    /// Buttons shown at the trailing end of the status bar.
    let accessory: AnyView
    let content: Content

    init(window: NSWindow?, landscape: Bool = false, fullBleed: Bool = false,
         accessory: AnyView = AnyView(EmptyView()), @ViewBuilder content: () -> Content) {
        self.window = window
        self.landscape = landscape
        self.fullBleed = fullBleed
        self.accessory = accessory
        self.content = content()
    }

    private var keySide: Edge.Set { landscape ? .vertical : .horizontal }
    private var otherSide: Edge.Set { landscape ? .horizontal : .vertical }

    var body: some View {
        ZStack {
            sideKeys

            RoundedRectangle(cornerRadius: PhoneMetrics.outerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.24), Color(white: 0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PhoneMetrics.outerRadius, style: .continuous)
                        .strokeBorder(Color(white: 0.5), lineWidth: 1.5)
                )
                .padding(keySide, PhoneMetrics.sideKeyInset)
                .accessibilityHidden(true)

            screen
                .background(fullBleed ? Color.black : Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.screenRadius, style: .continuous))
                .padding(otherSide, PhoneMetrics.bezel)
                .padding(keySide, PhoneMetrics.bezel + PhoneMetrics.sideKeyInset)
        }
    }

    // MARK: Screen layouts

    @ViewBuilder private var screen: some View {
        switch (landscape, fullBleed) {
        case (false, true):
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(portraitStatusBar, alignment: .top)
        case (false, false):
            VStack(spacing: 0) {
                portraitStatusBar
                content
                homeIndicator
            }
        case (true, true):
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    HStack(spacing: 0) {
                        islandColumn
                        VStack(spacing: 0) {
                            topBar(height: 40, leading: 10)
                            Spacer(minLength: 0)
                        }
                    }
                )
        case (true, false):
            HStack(spacing: 0) {
                islandColumn
                VStack(spacing: 0) {
                    topBar(height: 40, leading: 10)
                    content
                    homeIndicator
                }
            }
        }
    }

    private var portraitStatusBar: some View {
        ZStack {
            topBar(height: 54, leading: 28)
            dynamicIsland(width: 112, height: 32)
        }
        .frame(height: 54)
    }

    /// Landscape: the Dynamic Island sits in a column at the leading edge.
    private var islandColumn: some View {
        ZStack {
            WindowDragArea()
            dynamicIsland(width: 32, height: 112)
        }
        .frame(width: 54)
    }

    private func topBar(height: CGFloat, leading: CGFloat) -> some View {
        HStack(spacing: 0) {
            WindowControls(window: window)
                .padding(.leading, leading)
            WindowDragArea()
            HStack(spacing: 8) {
                accessory
                if !fullBleed {
                    HStack(spacing: 5) {
                        Image(systemName: "wifi")
                        Image(systemName: "battery.100")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
                }
            }
            .padding(.trailing, 22)
        }
        .frame(height: height)
    }

    private func dynamicIsland(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Color.black)
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }

    private var homeIndicator: some View {
        Capsule()
            .fill(Color.primary.opacity(0.35))
            .frame(width: 124, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .accessibilityHidden(true)
    }

    // MARK: Side keys

    @ViewBuilder private var sideKeys: some View {
        if landscape {
            VStack(alignment: .leading) {
                HStack(spacing: 14) {
                    sideKey(length: 28)
                    sideKey(length: 54)
                    sideKey(length: 54)
                }
                .padding(.leading, 150)
                Spacer()
                sideKey(length: 86)
                    .padding(.leading, 210)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
        } else {
            HStack(alignment: .top) {
                VStack(spacing: 14) {
                    sideKey(length: 28)
                    sideKey(length: 54)
                    sideKey(length: 54)
                }
                .padding(.top, 150)
                Spacer()
                sideKey(length: 86)
                    .padding(.top, 210)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityHidden(true)
        }
    }

    private func sideKey(length: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(white: 0.3))
            .frame(width: landscape ? length : 6, height: landscape ? 6 : length)
    }
}

// MARK: - Status bar buttons

private extension View {
    /// Small dark capsule used for buttons in the phone's status bar.
    func statusBarCapsule() -> some View {
        self
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 26, height: 22)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .contentShape(Capsule())
    }
}

struct RotateButton: View {
    @Binding var landscape: Bool

    var body: some View {
        Button {
            landscape.toggle()
        } label: {
            Image(systemName: landscape ? "rotate.left" : "rotate.right")
                .statusBarCapsule()
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: .command)
        .help(landscape ? "Rotate to portrait (⌘R)" : "Rotate to landscape (⌘R)")
        .accessibilityLabel(landscape ? "Rotate to portrait" : "Rotate to landscape")
    }
}

// MARK: - Close / minimize

struct WindowControls: View {
    let window: NSWindow?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            light(color: Color(red: 1.0, green: 0.37, blue: 0.34), symbol: "xmark", label: "Close") {
                window?.close()
            }
            light(color: Color(red: 1.0, green: 0.74, blue: 0.18), symbol: "minus", label: "Minimize") {
                window?.miniaturize(nil)
            }
        }
        .onHover { hovering = $0 }
    }

    private func light(color: Color, symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color)
                Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5)
                Image(systemName: symbol)
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundColor(Color.black.opacity(0.6))
                    .opacity(hovering ? 1 : 0)
            }
            .frame(width: 13, height: 13)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - AppKit bridges

/// Empty area that drags the window when clicked.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

/// Turns the hosting window into a frameless, transparent, phone-shaped window.
struct PhoneWindowConfigurator: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView { ConfigView(onWindow: onWindow) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    /// Turns the window between portrait and landscape, keeping its centre and scale.
    static func rotate(_ window: NSWindow, landscape: Bool) {
        let target = PhoneMetrics.size(landscape: landscape)
        let current = window.contentRect(forFrameRect: window.frame).size
        let scale = max(current.width, current.height) / max(target.width, target.height)
        var size = NSSize(width: target.width * scale, height: target.height * scale)

        // Fit on screen if the long side no longer fits in the new direction.
        if let visible = window.screen?.visibleFrame {
            let fit = min(1, visible.width / size.width, visible.height / size.height)
            size = NSSize(width: size.width * fit, height: size.height * fit)
        }

        window.contentAspectRatio = target
        window.contentMinSize = PhoneMetrics.minSize(landscape: landscape)

        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.midX - frame.width / 2, y: window.frame.midY - frame.height / 2)
        if let visible = window.screen?.visibleFrame {
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        }
        window.setFrame(frame, display: true, animate: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { window.invalidateShadow() }
    }

    final class ConfigView: NSView {
        private let onWindow: (NSWindow) -> Void
        private weak var configured: NSWindow?

        init(onWindow: @escaping (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window = window, window !== configured else { return }
            configured = window

            // No title bar, but keep close/minimize/resize behaviour (and ⌘W / ⌘M).
            window.styleMask = [.borderless, .closable, .miniaturizable, .resizable]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            window.contentAspectRatio = PhoneMetrics.portraitSize
            window.contentMinSize = PhoneMetrics.minSize(landscape: false)
            window.setContentSize(PhoneMetrics.portraitSize)
            window.center()

            onWindow(window)
            // Recompute the shadow from the phone outline once it has drawn.
            DispatchQueue.main.async { window.invalidateShadow() }
        }
    }
}
