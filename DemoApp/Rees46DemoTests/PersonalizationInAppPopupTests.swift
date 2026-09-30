import XCTest
@_spi(PersonalizationUI) import REES46

/// The in-app popup as the finished InAppPopup page draws it: a round cross over the content in the
/// corner of every view, the text buttons 12 apart in a modal and 16 in a fullscreen popup, and the
/// Elevation 3 shadow around the modal only.
final class PersonalizationInAppPopupTests: XCTestCase {

    private let views: [PersonalizationInAppPopup.ContentView] = [.image, .imageBackground, .text, .icon]

    private func popup(
        _ view: PersonalizationInAppPopup.ContentView = .text,
        presentation: PersonalizationInAppPopup.Presentation = .modal
    ) -> PersonalizationInAppPopup {
        let popup = PersonalizationInAppPopup()
        popup.presentation = presentation
        popup.contentView = view
        popup.title = "Title"
        popup.text = "Text"
        popup.actionText = "Go"
        popup.closeText = "Later"
        popup.frame = CGRect(x: 0, y: 0, width: 343, height: 520)
        popup.layoutIfNeeded()
        return popup
    }

    private func buttons(in view: UIView) -> [PersonalizationButton] {
        view.subviews.flatMap { subview -> [PersonalizationButton] in
            if let button = subview as? PersonalizationButton { return [button] }
            return buttons(in: subview)
        }
    }

    private func cross(of popup: PersonalizationInAppPopup) -> PersonalizationButton? {
        buttons(in: popup).first { $0.iconStart != nil }
    }

    func testTheCrossIsARoundOverlayInTheCornerInEveryView() {
        for view in views {
            let popup = popup(view)
            guard let cross = cross(of: popup) else { return XCTFail("\(view): no cross") }
            let frame = cross.convert(cross.bounds, to: popup)

            XCTAssertTrue(cross.rounded, "\(view)")
            XCTAssertEqual(cross.layer.cornerRadius, cross.bounds.height / 2, "\(view): a circle")
            XCTAssertFalse(cross.superview is UIStackView, "\(view): not a row of the column")
            XCTAssertEqual(frame.minY, 20, "\(view)")
            XCTAssertEqual(frame.maxX, popup.bounds.width - 20, "\(view)")
        }
    }

    func testTheCrossIsDarkOverAPhoto() {
        XCTAssertTrue(cross(of: popup(.image))?.onDark == true)
        XCTAssertTrue(cross(of: popup(.imageBackground))?.onDark == true)
        XCTAssertTrue(cross(of: popup(.text))?.onDark == false)
        XCTAssertTrue(cross(of: popup(.icon))?.onDark == false)
    }

    func testButtonsAre12ApartInAModalAnd16InAFullscreenPopup() {
        for (presentation, gap) in [(PersonalizationInAppPopup.Presentation.modal, CGFloat(12)), (.fullscreen, 16)] {
            let popup = popup(presentation: presentation)
            let texts = buttons(in: popup).filter { $0.text != nil }
            guard let action = texts.first(where: { $0.text == "Go" }),
                  let close = texts.first(where: { $0.text == "Later" }) else { return XCTFail("no buttons") }

            let top = action.convert(action.bounds, to: popup).maxY
            XCTAssertEqual(close.convert(close.bounds, to: popup).minY - top, gap, "\(presentation)")
        }
    }

    func testTheModalCastsTheElevation3ShadowAndTheFullscreenNone() {
        let modal = popup(presentation: .modal)
        XCTAssertFalse(modal.clipsToBounds, "clipping would cut the shadow off")
        XCTAssertEqual(modal.layer.shadowOpacity, 1)
        XCTAssertEqual(modal.layer.shadowOffset.height, 23)
        XCTAssertEqual(modal.layer.shadowRadius, 11.5)
        XCTAssertNotNil(modal.layer.shadowPath)
        let second = modal.layer.sublayers?.first { $0.shadowOpacity > 0 && $0 !== modal.layer }
        XCTAssertEqual(second?.shadowOffset.height, 6, "the second layer of Elevation 3")
        XCTAssertEqual(second?.shadowRadius, 6.5)

        let fullscreen = popup(presentation: .fullscreen)
        XCTAssertEqual(fullscreen.layer.shadowOpacity, 0)
        XCTAssertFalse(fullscreen.layer.sublayers?.contains { $0.shadowOpacity > 0 } ?? false)
    }
}
