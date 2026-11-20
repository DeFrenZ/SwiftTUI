import Foundation

extension Control {
    /// The controls within this one that reach outside the bounds of the control holding them, where nothing draws the part outside: content its layout couldn't fit.
    var overflowingDescendants: [Control] {
        children.flatMap { child in
            let frame = child.layer.frame
            let fitsHorizontally = frame.position.column >= 0 && frame.position.column + frame.size.width <= layer.frame.size.width
            let fitsVertically = scrollsContentVertically || (frame.position.line >= 0 && frame.position.line + frame.size.height <= layer.frame.size.height)
            return (fitsHorizontally && fitsVertically ? [] : [child]) + child.overflowingDescendants
        }
    }
}
