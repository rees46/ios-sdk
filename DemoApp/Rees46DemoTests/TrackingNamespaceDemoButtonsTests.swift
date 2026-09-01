import XCTest
@testable import REES46

/// Drives the demo's tracking buttons the way a person does: finds each button on the live screen
/// by its accessibility identifier, fires it, and reads the alert its handler presents.
///
/// The handlers call `sdk.tracking.*` against the real API, so a green run means both that the
/// demo is wired to the namespace and that every method actually works end to end.
/// Scene-based window lookup needs iOS 13; the demo itself ships lower, the test does not.
@available(iOS 13.0, *)
final class TrackingNamespaceDemoButtonsTests: XCTestCase {

    /// Button identifier → the alert title its handler shows on success. Ordered the way the
    /// buttons sit on screen.
    private let buttons: [(identifier: String, successTitle: String)] = [
        ("tracking_product_view", "productView OK"),
        ("tracking_category_view", "categoryView OK"),
        ("tracking_search", "search OK"),
        ("tracking_add_to_cart", "addToCart OK"),
        ("tracking_sync_cart", "syncCart OK"),
        ("tracking_remove_from_cart", "removeFromCart OK"),
        ("tracking_add_to_favorites", "addToFavorites OK"),
        ("tracking_sync_favorites", "syncFavorites OK"),
        ("tracking_remove_from_favorites", "removeFromFavorites OK"),
        ("tracking_set_source", "setSource OK"),
    ]

    override func setUpWithError() throws {
        try super.setUpWithError()
        try waitForDemoSdk()
    }

    /// The host app initializes its SDK asynchronously on launch, and until it lands every
    /// handler answers "globalSDK is not initialized". `setSource` is the cheapest probe —
    /// it stores the source locally and touches no network.
    private func waitForDemoSdk() throws {
        let deadline = Date().addingTimeInterval(Constants.defaultTimeout)
        while true {
            let alert = try tapAndWaitForAlert("tracking_set_source")
            let title = alert.title
            try dismiss(alert)

            if title == "setSource OK" { return }
            if Date() >= deadline {
                return XCTFail("the demo SDK never initialized, last alert: \(title ?? "nil")")
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }

    func test_everyTrackingButton_isOnScreen() throws {
        for button in buttons {
            XCTAssertNotNil(
                try? findButton(button.identifier),
                "button \(button.identifier) is missing from the demo screen"
            )
        }
    }

    func test_everyTrackingButton_reportsSuccess() throws {
        for button in buttons {
            let alert = try tapAndWaitForAlert(button.identifier)
            XCTAssertEqual(
                alert.title,
                button.successTitle,
                "\(button.identifier) reported: \(alert.title ?? "nil") — \(alert.message ?? "")"
            )
            try dismiss(alert)
        }
    }

    // MARK: - Driving the screen

    private func tapAndWaitForAlert(_ identifier: String) throws -> UIAlertController {
        let button = try findButton(identifier)
        button.sendActions(for: .touchUpInside)

        try waitUntil("an alert for \(identifier)", timeout: Constants.defaultTimeout) {
            self.presentedAlert() != nil
        }
        return try XCTUnwrap(presentedAlert(), "no alert after tapping \(identifier)")
    }

    private func dismiss(_ alert: UIAlertController) throws {
        alert.dismiss(animated: false)
        try waitUntil("the alert to go away", timeout: Constants.defaultTimeout) {
            self.presentedAlert() == nil
        }
    }

    private func findButton(_ identifier: String) throws -> UIButton {
        let window = try XCTUnwrap(keyWindow(), "the demo app has no key window")
        let button = firstButton(in: window, identifier: identifier)
        return try XCTUnwrap(button, "no button with identifier \(identifier)")
    }

    private func firstButton(in view: UIView, identifier: String) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityIdentifier == identifier {
            return button
        }
        for subview in view.subviews {
            if let found = firstButton(in: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    /// The alert the demo handler presented, wherever it sits in the presentation chain.
    private func presentedAlert() -> UIAlertController? {
        var controller = keyWindow()?.rootViewController
        while let current = controller {
            if let alert = current as? UIAlertController {
                return alert
            }
            controller = current.presentedViewController
        }
        return nil
    }

    /// Spins the run loop until `condition` holds — the app and its network calls keep running.
    private func waitUntil(
        _ what: String,
        timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: () -> Bool
    ) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("timed out waiting for \(what)", file: file, line: line)
                throw XCTSkip("timed out waiting for \(what)")
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
