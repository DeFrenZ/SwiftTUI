import Foundation

public extension View {
    /// Moves the focus to the first selectable control within this view when it appears, away from wherever it was.
    ///
    /// A control appearing otherwise only takes the focus when nothing has it, so that one which was drawn first — say, a button under a list still being filled — keeps it.
    func takesFocusOnAppear() -> some View {
        TakesFocusOnAppear(content: self)
    }
}

private struct TakesFocusOnAppear<Content: View>: View, PrimitiveView, ModifierView {
    let content: Content

    static var size: Int? { Content.size }

    func buildNode(_ node: Node) {
        node.addNode(at: 0, Node(view: content.view))
    }

    func updateNode(_ node: Node) {
        node.view = self
        node.children[0].update(using: content.view)
    }

    func passControl(_ control: Control, node: Node) -> Control {
        if let focusControl = control.parent { return focusControl }
        let focusControl = TakesFocusOnAppearControl()
        focusControl.addSubview(control, at: 0)
        return focusControl
    }

    private class TakesFocusOnAppearControl: Control {
        /// Whether the focus moved here already: it moves once, when the view appears, and is the player's to move on from there.
        var tookFocus = false

        override func size(proposedSize: Size) -> Size {
            children[0].size(proposedSize: proposedSize)
        }

        override func layout(size: Size) {
            super.layout(size: size)
            children[0].layout(size: size)
            guard
                !tookFocus,
                let window = root.window,
                let responder = firstSelectableElement
            else { return }

            tookFocus = true
            guard window.firstResponder !== responder else { return }

            window.firstResponder?.resignFirstResponder()
            window.firstResponder = responder
            responder.becomeFirstResponder()
        }
    }
}
