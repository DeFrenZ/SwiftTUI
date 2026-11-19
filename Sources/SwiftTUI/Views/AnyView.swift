import Foundation

/// A type-erased view, for choosing at runtime among views of different types.
///
/// As in SwiftUI, while the erased view keeps its type the views below are updated in place, keeping their state; when its type changes, they are rebuilt from scratch.
public struct AnyView: View, PrimitiveView {
    private let erased: any View

    public init<V: View>(_ view: V) {
        erased = view
    }

    public init<V: View>(erasing view: V) {
        self.init(view)
    }

    static var size: Int? { nil }

    func buildNode(_ node: Node) {
        node.addNode(at: 0, Node(view: erased.view))
    }

    func updateNode(_ node: Node) {
        let last = node.view as! Self
        node.view = self
        guard ObjectIdentifier(type(of: last.erased)) == ObjectIdentifier(type(of: erased)) else {
            node.removeNode(at: 0)
            node.addNode(at: 0, Node(view: erased.view))
            return
        }
        node.children[0].update(using: erased.view)
    }
}
