import XCTest
@testable import REES46

/// Tests the `StoriesView` -> `communicationDelegate` bridge behind `shouldOpenLinkBySdk(url:)`,
/// which is what `StoryViewController.openUrl(link:)` consults before opening a story link.
///
/// `StoriesView` has no public initialiser (hosts wire it up in Interface Builder), so unlike
/// `StoriesLinkOptOutContractTests` this file needs `@testable` to construct one.
final class StoriesLinkOptOutBridgeTests: XCTestCase {

    // MARK: - Host doubles

    private final class LegacyDelegate: StoriesCommunicationProtocol {
        func receiveIosLink(text: String) {}
        func receiveSelectedProductData(products: StoriesElement) {}
        func receiveSelectedCarouselProductData(products: StoriesProduct) {}
        func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {}
    }

    private final class RoutingDelegate: StoriesCommunicationProtocol {
        private(set) var askedUrls: [String] = []

        func receiveIosLink(text: String) {}
        func receiveSelectedProductData(products: StoriesElement) {}
        func receiveSelectedCarouselProductData(products: StoriesProduct) {}
        func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {}

        func shouldOpenLinkBySdk(url: String) -> Bool {
            askedUrls.append(url)
            return false
        }
    }

    private func makeStoriesView() -> StoriesView {
        StoriesView(frame: CGRect(x: 0, y: 0, width: 300, height: 135))
    }

    // MARK: - Tests

    /// The scenario from the DEV-4306 report: `StoriesView` embedded without assigning a
    /// communication delegate at all. The SDK has to open the link itself, otherwise the
    /// button stays dead — which is the bug this ticket fixed.
    func testViewWithoutDelegateLetsSdkOpen() {
        let view = makeStoriesView()

        XCTAssertNil(view.communicationDelegate)
        XCTAssertTrue(view.shouldOpenLinkBySdk(url: "myshop://product/42"))
    }

    func testViewWithLegacyDelegateLetsSdkOpen() {
        let view = makeStoriesView()
        let host = LegacyDelegate()
        view.communicationDelegate = host

        XCTAssertTrue(view.shouldOpenLinkBySdk(url: "https://example.com/product/42"))
    }

    func testViewWithMigratedDelegateSuppressesOpening() {
        let view = makeStoriesView()
        let host = RoutingDelegate()
        view.communicationDelegate = host

        XCTAssertFalse(view.shouldOpenLinkBySdk(url: "myshop://cart"))
        XCTAssertEqual(host.askedUrls, ["myshop://cart"])
    }

    /// `communicationDelegate` is a weak reference. A host that has gone away must not leave
    /// stories with permanently dead buttons, and asking it must not crash.
    func testViewFallsBackToSdkOpeningAfterDelegateIsReleased() {
        let view = makeStoriesView()

        do {
            let host = RoutingDelegate()
            view.communicationDelegate = host
            XCTAssertFalse(view.shouldOpenLinkBySdk(url: "myshop://cart"))
        }

        XCTAssertNil(view.communicationDelegate, "The delegate is held weakly, so it is gone by now")
        XCTAssertTrue(
            view.shouldOpenLinkBySdk(url: "myshop://cart"),
            "A released host must not silently disable link opening"
        )
    }

    /// The host decides from the url alone, so it has to arrive exactly as the SDK is about to
    /// open it — no trimming, no escaping, no normalisation.
    func testUrlReachesTheHostVerbatim() {
        let view = makeStoriesView()
        let host = RoutingDelegate()
        view.communicationDelegate = host

        let urls = [
            "myshop://product/42?ref=stories&utm_source=push#reviews",
            "https://example.com/каталог/товар%201",
            "  https://example.com/padded  ",
            ""
        ]
        urls.forEach { _ = view.shouldOpenLinkBySdk(url: $0) }

        XCTAssertEqual(host.askedUrls, urls)
    }
}
