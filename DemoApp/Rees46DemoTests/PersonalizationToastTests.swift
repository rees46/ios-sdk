import XCTest
@_spi(PersonalizationUI) import REES46

/// The toast as the Stories frames place it: a 50-high pill 16 above the bottom (or below the top)
/// of the safe area, centred and no wider than the screen less 16 a side; one at a time, gone after
/// its duration, and transparent to touches.
final class PersonalizationToastTests: XCTestCase {

    private var container: UIView!

    override func setUp() {
        super.setUp()
        container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    }

    override func tearDown() {
        PersonalizationToast.dismiss()
        container = nil
        super.tearDown()
    }

    private func toasts() -> [PersonalizationToast] {
        container.subviews.compactMap { $0 as? PersonalizationToast }
    }

    private func frame(_ toast: PersonalizationToast) -> CGRect {
        container.layoutIfNeeded()
        return toast.frame
    }

    func testANewToastReplacesTheOneOnScreen() {
        PersonalizationToast.show("Copied", in: container)
        PersonalizationToast.show("Code copied to clipboard", in: container, position: .top)

        XCTAssertEqual(toasts().count, 1, "no stacking")
        XCTAssertEqual(toasts().first?.text, "Code copied to clipboard")
    }

    func testAtTheBottomAndAtTheTop16FromTheEdgeAndCentred() {
        guard let bottom = PersonalizationToast.show("Copied", in: container) else { return XCTFail("not shown") }
        let atBottom = frame(bottom)
        XCTAssertEqual(atBottom.height, 50, accuracy: 0.5, "16 + 18 + 16")
        XCTAssertEqual(atBottom.maxY, 844 - 16, accuracy: 0.01)
        XCTAssertEqual(atBottom.midX, 195, accuracy: 0.5)

        guard let top = PersonalizationToast.show("Copied", in: container, position: .top) else { return XCTFail("not shown") }
        XCTAssertEqual(frame(top).minY, 16, accuracy: 0.01)
    }

    func testLongTextWrapsInsideTheSideMargins() {
        let text = String(repeating: "Code copied to clipboard. ", count: 6)
        guard let toast = PersonalizationToast.show(text, in: container) else { return XCTFail("not shown") }
        container.layoutIfNeeded()
        let wrapped = frame(toast)

        XCTAssertGreaterThanOrEqual(wrapped.minX, 16 - 0.01)
        XCTAssertLessThanOrEqual(wrapped.maxX, 390 - 16 + 0.01)
        XCTAssertGreaterThan(wrapped.height, 50, "more than one line")
    }

    func testTouchesGoThroughToTheScreenUnderneath() {
        guard let toast = PersonalizationToast.show("Copied", in: container) else { return XCTFail("not shown") }
        let centre = CGPoint(x: frame(toast).midX, y: frame(toast).midY)

        XCTAssertFalse(toast.isUserInteractionEnabled)
        XCTAssertTrue(container.hitTest(centre, with: nil) === container)
    }

    func testItGoesAwayAfterItsDuration() {
        guard let toast = PersonalizationToast.show("Copied", in: container, duration: 0.1) else { return XCTFail("not shown") }
        let gone = expectation(for: NSPredicate { _, _ in toast.superview == nil }, evaluatedWith: nil)
        wait(for: [gone], timeout: 3)
    }

    func testThePillCastsTheElevation2Shadow() {
        let toast = PersonalizationToast(text: "Copied")
        toast.frame = CGRect(x: 0, y: 0, width: 120, height: 50)
        toast.layoutIfNeeded()

        XCTAssertEqual(toast.layer.shadowOpacity, 1)
        XCTAssertEqual(toast.layer.shadowOffset.height, 10)
        XCTAssertEqual(toast.layer.shadowRadius, 5)
        XCTAssertNotNil(toast.layer.shadowPath)
        let second = toast.layer.sublayers?.first { $0.shadowOpacity > 0 && $0 !== toast.layer }
        XCTAssertEqual(second?.shadowOffset.height, 3, "the second layer of Elevation 2")
        XCTAssertEqual(second?.shadowRadius, 3)
    }
}
