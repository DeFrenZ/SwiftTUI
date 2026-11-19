import XCTest
@testable import SwiftTUI

@MainActor final class ViewBuildTests: XCTestCase {
    func test_VStack_TupleView2() throws {
        struct MyView: View {
            var body: some View {
                VStack {
                    Text("One")
                    Text("Two")
                }
            }
        }

        let control = try buildView(MyView())

        XCTAssertEqual(control.treeDescription, """
            → VStackControl
              → TextControl
              → TextControl
            """)
    }

    func test_conditional_VStack() throws {
        struct MyView: View {
            @State var value = true

            var body: some View {
                if value {
                    VStack {
                        Text("One")
                    }
                }
            }
        }

        let control = try buildView(MyView())

        XCTAssertEqual(control.treeDescription, """
            → VStackControl
              → TextControl
            """)
    }

    func test_AnyView_updatesInPlaceWhileItsTypeStays() throws {
        let node = Node(view: VStack(content: AnyView(Text("One"))).view)
        node.build()
        let text = try XCTUnwrap(node.control?.children.first)

        node.update(using: VStack(content: AnyView(Text("Two"))).view)

        XCTAssertTrue(node.control?.children.first === text)
    }

    func test_AnyView_rebuildsWhenItsTypeChanges() throws {
        let node = Node(view: VStack(content: AnyView(Text("One"))).view)
        node.build()

        node.update(using: VStack(content: AnyView(VStack { Text("One") })).view)

        XCTAssertEqual(try XCTUnwrap(node.control?.children.first).treeDescription, """
            → VStackControl
              → TextControl
            """)
    }

    private func buildView<V: View>(_ view: V) throws -> Control {
        let node = Node(view: VStack(content: view).view)
        node.build()
        return try XCTUnwrap(node.control?.children.first)
    }

}
