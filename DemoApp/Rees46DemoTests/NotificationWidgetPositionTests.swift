import XCTest
@testable import REES46

/// A popup's `position` picks its dialog. The three known ones keep theirs; no position, or one this
/// SDK does not know, comes out fullscreen — as on Android, and as the product decided it should.
final class NotificationWidgetPositionTests: XCTestCase {

    /// Catches the dialog instead of presenting it: the test has no window to present in.
    private final class HostViewController: UIViewController {
        var shown: UIViewController?

        override func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
            shown = viewController
        }
    }

    private func dialog(position: String) -> UIViewController? {
        let host = HostViewController()
        let popup = Popup(json: [
            "id": 1,
            "position": position,
            "components": #"{"header": "Title", "text": "Text"}"#,
            "popup_actions": #"{"link": {"button_text": "Go", "link_ios": "https://example.com"}}"#
        ])
        _ = NotificationWidget(parentViewController: host, popup: popup)
        return host.shown
    }

    func testKnownPositionsKeepTheirDialogs() {
        XCTAssertTrue(dialog(position: "centered") is AlertDialog)
        XCTAssertTrue(dialog(position: "fixed_bottom") is BottomDialog)
        XCTAssertTrue(dialog(position: "top") is TopDialog)
    }

    func testMissingOrUnknownPositionComesOutFullscreen() {
        XCTAssertTrue(dialog(position: "") is FullScreenDialog)
        XCTAssertTrue(dialog(position: "somewhere_new") is FullScreenDialog)
        XCTAssertTrue(Popup(json: ["id": 1]).position.isEmpty, "a popup without the field has an empty position")
    }

    func testTheFullscreenDialogShowsTheViewModel() {
        guard let dialog = dialog(position: "") as? FullScreenDialog else { return XCTFail("not fullscreen") }
        dialog.loadViewIfNeeded()

        let texts = labels(in: dialog.view).compactMap(\.text)
        XCTAssertTrue(texts.contains("Title"))
        XCTAssertTrue(texts.contains("Text"))
        let shown = buttons(in: dialog.view).filter { !$0.isHidden }
        XCTAssertEqual(shown.map { $0.title(for: .normal) }, ["Go"], "only the button the popup has")
        XCTAssertEqual(buttons(in: dialog.view).filter(\.isHidden).count, 1, "no empty dismiss button")
        XCTAssertTrue(dialog.viewModel.isImageContainerHidden)
    }

    private func labels(in view: UIView) -> [UILabel] {
        view.subviews.flatMap { subview -> [UILabel] in
            (subview as? UILabel).map { [$0] } ?? labels(in: subview)
        }
    }

    private func buttons(in view: UIView) -> [DialogActionButton] {
        view.subviews.flatMap { subview -> [DialogActionButton] in
            (subview as? DialogActionButton).map { [$0] } ?? buttons(in: subview)
        }
    }
}
