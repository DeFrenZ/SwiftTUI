import Foundation
#if os(macOS)
import AppKit
#endif

@MainActor public class Application {
    private let node: Node
    let window: Window
    private let control: Control
    /// What draws the window on the terminal, or `nil` for an application drawing nowhere.
    private let renderer: Renderer?

    private let runLoopType: RunLoopType

    private var arrowKeyParser = ArrowKeyParser()

    private var invalidatedNodes: [Node] = []
    private var updateScheduled = false

    /// Hears of the application's ``AccessibilitySnapshot`` each time it changes.
    private let accessibilityObserver: ((AccessibilitySnapshot) -> Void)?
    private var publishedAccessibilitySnapshot: AccessibilitySnapshot?

    /// An application drawing `rootView` on the terminal, telling `accessibilityObserver` of what it shows each time that changes.
    ///
    /// The observer is how something outside the terminal follows the application without reading its output, such as a test driving it through a pseudo-terminal.
    public init<I: View>(rootView: I, runLoopType: RunLoopType = .dispatch, accessibilityObserver: ((AccessibilitySnapshot) -> Void)? = nil) {
        self.runLoopType = runLoopType
        self.accessibilityObserver = accessibilityObserver

        node = Node(view: VStack(content: rootView).view)
        node.build()

        control = node.control!

        window = Window()
        window.addControl(control)

        window.firstResponder = control.firstSelectableElement
        window.firstResponder?.becomeFirstResponder()

        let renderer = Renderer(layer: window.layer)
        self.renderer = renderer
        window.layer.renderer = renderer

        node.application = self
        renderer.application = self
    }

    /// An application drawing `rootView` nowhere, in a window of `size`, to drive with ``handle(input:)`` and read back through ``window``.
    ///
    /// It reads no input and writes nothing to the terminal; invalidated views update on the main queue, as they do in a running application.
    init<I: View>(headlessRootView rootView: I, size: Size) {
        runLoopType = .dispatch
        accessibilityObserver = nil

        node = Node(view: VStack(content: rootView).view)
        node.build()

        control = node.control!

        window = Window()
        window.addControl(control)
        window.layer.frame.size = size

        window.firstResponder = control.firstSelectableElement
        window.firstResponder?.becomeFirstResponder()

        renderer = nil

        node.application = self
        control.layout(size: size)
    }

    var stdInSource: DispatchSourceRead?

    public enum RunLoopType {
        /// The default option, using Dispatch for the main run loop.
        case dispatch

        #if os(macOS)
        /// This creates and runs an NSApplication with an associated run loop. This allows you
        /// e.g. to open NSWindows running simultaneously to the terminal app. This requires macOS
        /// and AppKit.
        case cocoa
        #endif
    }

    public func start() {
        setInputMode()
        updateWindowSize()
        control.layout(size: window.layer.frame.size)
        renderer?.draw()
        publishAccessibilitySnapshot()

        let stdInSource = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: .main)
        stdInSource.setEventHandler(qos: .default, flags: [], handler: { [weak self] in self?.handleInput() })
        stdInSource.resume()
        self.stdInSource = stdInSource

        let sigWinChSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main)
        sigWinChSource.setEventHandler(qos: .default, flags: [], handler: { [weak self] in self?.handleWindowSizeChange() })
        sigWinChSource.resume()

        signal(SIGINT, SIG_IGN)
        let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigIntSource.setEventHandler(qos: .default, flags: [], handler: { [weak self] in self?.stop() })
        sigIntSource.resume()

        switch runLoopType {
        case .dispatch:
            dispatchMain()
        #if os(macOS)
        case .cocoa:
            NSApplication.shared.setActivationPolicy(.accessory)
            NSApplication.shared.run()
        #endif
        }
    }

    private func setInputMode() {
        var tattr = termios()
        tcgetattr(STDIN_FILENO, &tattr)
        tattr.c_lflag &= ~tcflag_t(ECHO | ICANON)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &tattr);
    }

    private func handleInput() {
        let data = FileHandle.standardInput.availableData

        guard let string = String(data: data, encoding: .utf8) else {
            return
        }

        handle(input: string)
    }

    /// Handles `string` as typed input: arrow keys move the focus, and every other character goes to the focused control.
    func handle(input string: String) {
        for char in string {
            if arrowKeyParser.parse(character: char) {
                guard let key = arrowKeyParser.arrowKey else { continue }
                arrowKeyParser.arrowKey = nil
                if key == .down {
                    if let next = window.firstResponder?.selectableElement(below: 0) {
                        window.firstResponder?.resignFirstResponder()
                        window.firstResponder = next
                        window.firstResponder?.becomeFirstResponder()
                    }
                } else if key == .up {
                    if let next = window.firstResponder?.selectableElement(above: 0) {
                        window.firstResponder?.resignFirstResponder()
                        window.firstResponder = next
                        window.firstResponder?.becomeFirstResponder()
                    }
                } else if key == .right {
                    if let next = window.firstResponder?.selectableElement(rightOf: 0) {
                        window.firstResponder?.resignFirstResponder()
                        window.firstResponder = next
                        window.firstResponder?.becomeFirstResponder()
                    }
                } else if key == .left {
                    if let next = window.firstResponder?.selectableElement(leftOf: 0) {
                        window.firstResponder?.resignFirstResponder()
                        window.firstResponder = next
                        window.firstResponder?.becomeFirstResponder()
                    }
                }
            } else if char == ASCII.EOT {
                stop()
            } else {
                window.firstResponder?.handleEvent(char)
            }
        }
    }

    func invalidateNode(_ node: Node) {
        invalidatedNodes.append(node)
        scheduleUpdate()
    }

    func scheduleUpdate() {
        if !updateScheduled {
            DispatchQueue.main.async { self.update() }
            updateScheduled = true
        }
    }

    private func update() {
        updateScheduled = false

        for node in invalidatedNodes {
            node.update(using: node.view)
        }
        invalidatedNodes = []

        control.layout(size: window.layer.frame.size)
        if let renderer {
            renderer.update()
        } else {
            window.layer.invalidated = nil
        }
        publishAccessibilitySnapshot()
    }

    /// What the application shows, published.
    var accessibilitySnapshot: AccessibilitySnapshot {
        window.accessibilitySnapshot
    }

    private func publishAccessibilitySnapshot() {
        guard let accessibilityObserver else { return }

        let snapshot = accessibilitySnapshot
        guard snapshot != publishedAccessibilitySnapshot else { return }

        publishedAccessibilitySnapshot = snapshot
        accessibilityObserver(snapshot)
    }

    private func handleWindowSizeChange() {
        updateWindowSize()
        control.layer.invalidate()
        update()
    }

    private func updateWindowSize() {
        var size = winsize()
        guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0,
              size.ws_col > 0, size.ws_row > 0 else {
            assertionFailure("Could not get window size")
            return
        }
        window.layer.frame.size = Size(width: Extended(Int(size.ws_col)), height: Extended(Int(size.ws_row)))
        renderer?.setCache()
    }

    private func stop() {
        renderer?.stop()
        resetInputMode() // Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
        exit(0)
    }

    /// Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
    private func resetInputMode() {
        // Reset ECHO and ICANON values:
        var tattr = termios()
        tcgetattr(STDIN_FILENO, &tattr)
        tattr.c_lflag |= tcflag_t(ECHO | ICANON)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &tattr);
    }

}
