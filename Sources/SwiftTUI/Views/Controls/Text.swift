import Foundation

public struct Text: View, PrimitiveView {
    private var text: String?
    
    private var _attributedText: Any?
    
    @available(macOS 12, *)
    private var attributedText: AttributedString? { _attributedText as? AttributedString }
    
    @Environment(\.foregroundColor) private var foregroundColor: Color
    @Environment(\.bold) private var bold: Bool
    @Environment(\.italic) private var italic: Bool
    @Environment(\.underline) private var underline: Bool
    @Environment(\.strikethrough) private var strikethrough: Bool
    
    public init(_ text: String) {
        self.text = text
    }
    
    @available(macOS 12, *)
    public init(_ attributedText: AttributedString) {
        self._attributedText = attributedText
    }
    
    static var size: Int? { 1 }
    
    func buildNode(_ node: Node) {
        setupEnvironmentProperties(node: node)
        node.control = TextControl(
            text: text,
            attributedText: _attributedText,
            foregroundColor: foregroundColor,
            bold: bold,
            italic: italic,
            underline: underline,
            strikethrough: strikethrough
        )
    }
    
    func updateNode(_ node: Node) {
        setupEnvironmentProperties(node: node)
        node.view = self
        let control = node.control as! TextControl
        control.text = text
        control._attributedText = _attributedText
        control.foregroundColor = foregroundColor
        control.bold = bold
        control.italic = italic
        control.underline = underline
        control.strikethrough = strikethrough
        control.layer.invalidate()
    }
    
    private class TextControl: Control {
        var text: String? {
            didSet { wrapping = nil }
        }
        
        var _attributedText: Any? {
            didSet { wrapping = nil }
        }

        /// The lines the text last wrapped into, and the width it wrapped to.
        private var wrapping: (width: Extended, lines: [Range<Int>])?
        
        @available(macOS 12, *)
        var attributedText: AttributedString? { _attributedText as? AttributedString }
        
        var foregroundColor: Color
        var bold: Bool
        var italic: Bool
        var underline: Bool
        var strikethrough: Bool
        
        init(
            text: String?,
            attributedText: Any?,
            foregroundColor: Color,
            bold: Bool,
            italic: Bool,
            underline: Bool,
            strikethrough: Bool
        ) {
            self.text = text
            self._attributedText = attributedText
            self.foregroundColor = foregroundColor
            self.bold = bold
            self.italic = italic
            self.underline = underline
            self.strikethrough = strikethrough
        }
        
        override func size(proposedSize: Size) -> Size {
            let lines = lines(fittingWidth: proposedSize.width)
            return Size(width: Extended(lines.map(\.count).max() ?? 0), height: Extended(lines.count))
        }
        
        override func cell(at position: Position) -> Cell? {
            let lines = lines(fittingWidth: layer.frame.size.width)
            guard position.line.intValue < lines.count else { return nil }
            let line = lines[position.line.intValue]
            guard position.column < Extended(line.count) else { return .init(char: " ") }
            let offset = line.lowerBound + position.column.intValue
            if #available(macOS 12, *), let attributedText {
                let characters = attributedText.characters
                let i = characters.index(characters.startIndex, offsetBy: offset)
                let char = attributedText[i ..< characters.index(after: i)]
                let cellAttributes = CellAttributes(
                    bold: char.bold ?? bold,
                    italic: char.italic ?? italic,
                    underline: char.underline ?? underline,
                    strikethrough: char.strikethrough ?? strikethrough,
                    inverted: char.inverted ?? false
                )
                return Cell(
                    char: char.characters[char.startIndex],
                    foregroundColor: char.foregroundColor ?? foregroundColor,
                    backgroundColor: char.backgroundColor,
                    attributes: cellAttributes
                )
            }
            if let text {
                let cellAttributes = CellAttributes(
                    bold: bold,
                    italic: italic,
                    underline: underline,
                    strikethrough: strikethrough
                )
                return Cell(
                    char: text[text.index(text.startIndex, offsetBy: offset)],
                    foregroundColor: foregroundColor,
                    attributes: cellAttributes
                )
            }
            return nil
        }
        
        /// The character ranges of the lines the text wraps into to fit `width`, as SwiftUI wraps text: at the last space that fits, or within a word longer than the whole width.
        ///
        /// A space a line breaks at belongs to neither line.
        private func lines(fittingWidth width: Extended) -> [Range<Int>] {
            if let wrapping, wrapping.width == width {
                return wrapping.lines
            }
            let lines = Self.lines(of: characters, fittingWidth: width)
            wrapping = (width, lines)
            return lines
        }

        private static func lines(of characters: [Character], fittingWidth width: Extended) -> [Range<Int>] {
            guard width != .infinity, characters.count > width.intValue else { return [0 ..< characters.count] }
            let width = max(width.intValue, 1)
            var lines: [Range<Int>] = []
            var start = 0
            while start < characters.count {
                if !lines.isEmpty {
                    while start < characters.count, characters[start] == " " { start += 1 }
                    guard start < characters.count else { break }
                }
                let limit = start + width
                guard limit < characters.count else {
                    lines.append(start ..< characters.count)
                    break
                }
                if let space = characters[start ... limit].lastIndex(of: " "), space > start {
                    lines.append(start ..< space)
                    start = space
                } else {
                    lines.append(start ..< limit)
                    start = limit
                }
            }
            return lines
        }

        private var characters: [Character] {
            if #available(macOS 12, *), let attributedText {
                return Array(attributedText.characters)
            }
            return Array(text ?? "")
        }

    }
}
