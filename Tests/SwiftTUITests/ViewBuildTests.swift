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

    func test_Button_performsTheActionOfItsLatestUpdate() throws {
        var performed: [String] = []
        let node = Node(view: VStack(content: Button("Go") { performed.append("first") }).view)
        node.build()

        node.update(using: VStack(content: Button("Go") { performed.append("second") }).view)
        try XCTUnwrap(node.control?.children.first).handleEvent("\n")

        XCTAssertEqual(performed, ["second"])
    }

    func test_Text_wrapsAtTheLastSpaceThatFits() throws {
        let control = try buildView(Text("one two three"))

        XCTAssertEqual(control.size(proposedSize: Size(width: 8, height: .infinity)), Size(width: 7, height: 2))
        control.layout(size: Size(width: 8, height: 2))
        XCTAssertEqual(lines(of: control, size: Size(width: 8, height: 2)), ["one two ", "three   "])
    }

    func test_Text_breaksAWordLongerThanTheWidth() throws {
        let control = try buildView(Text("abcdefgh ij"))

        control.layout(size: Size(width: 4, height: 3))
        XCTAssertEqual(lines(of: control, size: Size(width: 4, height: 3)), ["abcd", "efgh", "ij  "])
    }

    func test_Text_staysOnOneLineWhenItFits() throws {
        let control = try buildView(Text("one two"))

        XCTAssertEqual(control.size(proposedSize: Size(width: .infinity, height: .infinity)), Size(width: 7, height: 1))
        XCTAssertEqual(control.size(proposedSize: Size(width: 7, height: .infinity)), Size(width: 7, height: 1))
    }

    func test_ScrollView_wrapsTextToItsWidth() throws {
        let control = try buildView(ScrollView { Text("one two three") })

        control.layout(size: Size(width: 8, height: 4))
        XCTAssertEqual(try XCTUnwrap(control.children.first).layer.frame.size, Size(width: 7, height: 2))
    }

    func test_overflowingDescendants_findsWhatAFrameCantFit() throws {
        let node = Node(view: VStack(content: VStack { Text("fits"); Text("runs past") }.frame(maxWidth: 6)).view)
        node.build()
        let control = try XCTUnwrap(node.control)
        control.layout(size: Size(width: 6, height: 1))

        XCTAssertEqual(control.overflowingDescendants.count, 1)
    }

    func test_overflowingDescendants_letsScrolledContentRunPast() throws {
        let node = Node(view: VStack(content: ScrollView { Text("one"); Text("two"); Text("three") }).view)
        node.build()
        let control = try XCTUnwrap(node.control)
        control.layout(size: Size(width: 5, height: 1))

        XCTAssertEqual(control.overflowingDescendants.count, 0)
    }

    func test_headlessApplication_handlesTypedInput() {
        var performed: [String] = []
        let application = Application(
            headlessRootView: VStack { Button("One") { performed.append("one") }; Button("Two") { performed.append("two") } },
            size: Size(width: 5, height: 2))

        application.handle(input: "\u{1b}[B\n")

        XCTAssertEqual(performed, ["two"])
    }

    func test_takesFocusOnAppear_movesTheFocusFromWhatHadIt() {
        var performed: [String] = []
        let application = Application(
            headlessRootView: VStack { Button("One") { performed.append("one") }; Button("Two") { performed.append("two") }.takesFocusOnAppear() },
            size: Size(width: 5, height: 2))

        application.handle(input: "\n")

        XCTAssertEqual(performed, ["two"])
    }

    private func lines(of control: Control, size: Size) -> [String] {
        (0 ..< size.height.intValue).map { line in
            String((0 ..< size.width.intValue).map { column in
                control.cell(at: Position(column: Extended(column), line: Extended(line)))?.char ?? "?"
            })
        }
    }

    private func buildView<V: View>(_ view: V) throws -> Control {
        let node = Node(view: VStack(content: view).view)
        node.build()
        return try XCTUnwrap(node.control?.children.first)
    }

}
