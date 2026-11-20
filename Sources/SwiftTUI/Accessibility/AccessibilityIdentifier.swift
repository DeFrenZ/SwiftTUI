import Foundation

public extension View {
    /// Publishes this view in the application's ``AccessibilitySnapshot`` under `identifier`, with the text it draws and where.
    ///
    /// The identifier names the element for whoever reads the snapshot, such as a test driving the application from outside, so that it finds a control without matching its words.
    func accessibilityIdentifier(_ identifier: String) -> some View {
        AccessibilityIdentifierView(content: self, identifier: identifier)
    }
}

private struct AccessibilityIdentifierView<Content: View>: View, PrimitiveView, ModifierView {
    let content: Content
    let identifier: String

    static var size: Int? { Content.size }

    func buildNode(_ node: Node) {
        node.controls = WeakSet<Control>()
        node.addNode(at: 0, Node(view: content.view))
    }

    func updateNode(_ node: Node) {
        node.view = self
        node.children[0].update(using: content.view)
        for control in node.controls?.values ?? [] {
            (control as? AccessibilityElementControl)?.identifier = identifier
        }
    }

    func passControl(_ control: Control, node: Node) -> Control {
        if let elementControl = control.parent { return elementControl }
        let elementControl = AccessibilityElementControl(identifier: identifier)
        elementControl.addSubview(control, at: 0)
        node.controls?.add(elementControl)
        return elementControl
    }
}

/// A control drawing nothing of its own, which publishes the one it holds as an accessibility element.
final class AccessibilityElementControl: Control {
    var identifier: String

    init(identifier: String) {
        self.identifier = identifier
    }

    override func size(proposedSize: Size) -> Size {
        children[0].size(proposedSize: proposedSize)
    }

    override func layout(size: Size) {
        super.layout(size: size)
        children[0].layout(size: size)
    }
}
