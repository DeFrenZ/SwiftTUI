import Foundation
import Observation

/// This wraps a composed (user-defined) view, so that it can be used in a view graph node.
struct ComposedView<I: View>: GenericView {
    let view: I

    func buildNode(_ node: Node) {
        view.setupStateProperties(node: node)
        view.setupEnvironmentProperties(node: node)
        #if os(macOS)
        view.setupObservedObjectProperties(node: node)
        #endif
        node.addNode(at: 0, Node(view: observedBody(of: node).view))
    }

    func updateNode(_ node: Node) {
        view.setupStateProperties(node: node)
        view.setupEnvironmentProperties(node: node)
        #if os(macOS)
        // The updated view may hold different objects than the one the node was built with.
        view.setupObservedObjectProperties(node: node)
        #endif
        node.view = self
        node.children[0].update(using: observedBody(of: node).view)
    }

    static var size: Int? {
        I.Body.size
    }

    /// The view's body, invalidating `node` at the next change of any `@Observable` property the body read.
    ///
    /// Like SwiftUI, this tracks what the body actually reads, wherever the model comes from: a stored property, the environment, or an object reached through another. Each evaluation subscribes once, and every update evaluates the body again, so a node stays subscribed for as long as it is drawn.
    private func observedBody(of node: Node) -> I.Body {
        withObservationTracking {
            view.body
        } onChange: { [weak node] in
            // Observation reports a change before it is applied, from whichever thread applies it; the update has to read the new value, on the main thread.
            DispatchQueue.main.async {
                guard let node else { return }
                node.root.application?.invalidateNode(node)
            }
        }
    }
}
