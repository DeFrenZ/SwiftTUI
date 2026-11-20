import Foundation

/// What an application publishes of itself at one moment: its identified elements, and where the focus is.
///
/// Built from what the window draws, so it says what a player would see: an element's label is the text it draws, and its frame is where it draws it, scrolled out of view included.
public struct AccessibilitySnapshot: Codable, Equatable, Sendable {
    /// The identified elements outside any other, in drawing order.
    public var elements: [AccessibilityElement]
    /// Where the focused control is, or `nil` when no control has the focus.
    public var focusedFrame: AccessibilityFrame?

    public init(elements: [AccessibilityElement], focusedFrame: AccessibilityFrame?) {
        self.elements = elements
        self.focusedFrame = focusedFrame
    }
}

/// A view published with ``View/accessibilityIdentifier(_:)``.
public struct AccessibilityElement: Codable, Equatable, Sendable {
    public var identifier: String
    /// The text the element draws, line by line, without the spaces trailing each line or the empty lines after the last.
    public var label: String
    /// Where the element is drawn, in the window's cells.
    public var frame: AccessibilityFrame
    /// Whether the focus is on the element or on a control within it.
    public var isFocused: Bool
    /// The identified elements within this one, in drawing order.
    public var children: [AccessibilityElement]

    public init(identifier: String, label: String, frame: AccessibilityFrame, isFocused: Bool, children: [AccessibilityElement]) {
        self.identifier = identifier
        self.label = label
        self.frame = frame
        self.isFocused = isFocused
        self.children = children
    }
}

/// A rectangle of the window's cells, from its top-left one.
///
/// It can lie partly or wholly outside the window, for content scrolled out of view.
public struct AccessibilityFrame: Codable, Equatable, Sendable {
    public var column: Int
    public var line: Int
    public var width: Int
    public var height: Int

    public init(column: Int, line: Int, width: Int, height: Int) {
        self.column = column
        self.line = line
        self.width = width
        self.height = height
    }
}

// MARK: - Building

extension Window {
    /// The window as it stands, published.
    var accessibilitySnapshot: AccessibilitySnapshot {
        AccessibilitySnapshot(
            elements: controls.flatMap { $0.accessibilityElements(focused: firstResponder) },
            focusedFrame: firstResponder.map { AccessibilityFrame($0.frameInWindow) })
    }
}

extension Control {
    /// The identified elements at or within this control, the outermost ones only, each holding its own.
    fileprivate func accessibilityElements(focused: Control?) -> [AccessibilityElement] {
        let children = children.flatMap { $0.accessibilityElements(focused: focused) }
        guard let element = self as? AccessibilityElementControl else { return children }

        return [
            AccessibilityElement(
                identifier: element.identifier,
                label: drawnText,
                frame: AccessibilityFrame(frameInWindow),
                isFocused: focused.map { $0 === self || $0.isDescendant(of: self) } ?? false,
                children: children),
        ]
    }

    /// Where this control is drawn, in the window's cells.
    var frameInWindow: Rect {
        var position = layer.frame.position
        var ancestor = parent
        while let current = ancestor {
            position = position + current.layer.frame.position
            ancestor = current.parent
        }
        return Rect(position: position, size: layer.frame.size)
    }

    /// The text this control and those within it draw, whatever covers it in the window.
    private var drawnText: String {
        let size = layer.frame.size
        let lines = (0 ..< size.height.intValue).map { line in
            String((0 ..< size.width.intValue).map { column in
                layer.cell(at: Position(column: Extended(column), line: Extended(line)))?.char ?? " "
            })
            .replacing(/\ +$/, with: "")
        }
        return lines.reversed().drop(while: \.isEmpty).reversed().joined(separator: "\n")
    }
}

extension AccessibilityFrame {
    fileprivate init(_ rect: Rect) {
        self.init(column: rect.position.column.intValue, line: rect.position.line.intValue, width: rect.size.width.intValue, height: rect.size.height.intValue)
    }
}
