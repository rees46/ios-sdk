import XCTest
import REES46

/// Migration and contract tests for `shouldOpenLinkBySdk(url:)` — the opt-out that keeps the
/// SDK from opening a story link the host routes itself (DEV-4306).
///
/// This file imports `REES46` plainly instead of `@testable` on purpose: every conformer below
/// is written exactly the way host app code is written, so the file stops compiling if the
/// opt-out ever stops being reachable from outside the module (for example if `public` is
/// dropped from the protocol extension holding the default).
final class StoriesLinkOptOutContractTests: XCTestCase {

    // MARK: - Host doubles

    /// An integration written before DEV-4306: it implements only the four original
    /// requirements and has never heard of the opt-out.
    private final class LegacyDelegate: StoriesCommunicationProtocol {
        func receiveIosLink(text: String) {}
        func receiveSelectedProductData(products: StoriesElement) {}
        func receiveSelectedCarouselProductData(products: StoriesProduct) {}
        func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {}
    }

    /// An integration that migrated and routes every story link through its own router.
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

    /// Partial adoption: the host owns its own url scheme and leaves web links to the SDK.
    private final class SchemeAwareDelegate: StoriesCommunicationProtocol {
        func receiveIosLink(text: String) {}
        func receiveSelectedProductData(products: StoriesElement) {}
        func receiveSelectedCarouselProductData(products: StoriesProduct) {}
        func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {}

        func shouldOpenLinkBySdk(url: String) -> Bool {
            !url.hasPrefix("myshop://")
        }
    }

    /// A host bridge conforming to the second public protocol without adopting the opt-out.
    private final class LegacyLinkBridge: StoriesViewLinkProtocol {
        func linkIosExternalUse(url: String) {}
        func sendStructSelectedStorySlide(storySlide: StoriesElement) {}
        func structOfSelectedCarouselProduct(product: StoriesProduct) {}
        func sendStructSelectedPromocodeSlide(promoCodeSlide: StoriesPromoCodeElement) {}
        func reloadStoriesCollectionSubviews() {}
        func updateBgColor() {}
    }

    // MARK: - Migration of existing integrations

    func testIntegrationWrittenBeforeTheOptOutKeepsSdkOpening() {
        let delegate: StoriesCommunicationProtocol = LegacyDelegate()

        XCTAssertTrue(
            delegate.shouldOpenLinkBySdk(url: "https://example.com/product/42"),
            "An integration that predates the opt-out must keep the SDK-opens behaviour without changing a line"
        )
    }

    func testLinkBridgeWrittenBeforeTheOptOutKeepsSdkOpening() {
        let bridge: StoriesViewLinkProtocol = LegacyLinkBridge()

        XCTAssertTrue(bridge.shouldOpenLinkBySdk(url: "https://example.com/product/42"))
    }

    // MARK: - Reaching a migrated host

    /// The default lives in a protocol extension while the requirement is declared in the
    /// protocol body — that is what makes a host override reachable through the existential the
    /// SDK actually holds. Moving the requirement into the extension would quietly restore the
    /// double-open bug for everyone who adopted the opt-out, and this test is what catches it.
    func testHostOverrideIsReachedThroughTheExistentialTheSdkHolds() {
        let host = RoutingDelegate()
        let delegate: StoriesCommunicationProtocol = host

        XCTAssertFalse(delegate.shouldOpenLinkBySdk(url: "myshop://product/42"))
        XCTAssertEqual(host.askedUrls, ["myshop://product/42"])
    }

    // MARK: - Partial adoption

    func testHostCanSuppressOnlyItsOwnSchemeAndLeaveWebLinksToTheSdk() {
        let delegate: StoriesCommunicationProtocol = SchemeAwareDelegate()

        XCTAssertFalse(
            delegate.shouldOpenLinkBySdk(url: "myshop://product/42"),
            "The host routes its own scheme, so the SDK must not open it as well"
        )
        XCTAssertTrue(
            delegate.shouldOpenLinkBySdk(url: "https://example.com/product/42"),
            "A host opting out of its own scheme still expects the SDK to open plain web links"
        )
    }

    /// The decision is taken per url, so adopting the opt-out must not latch: a suppressed link
    /// cannot leave the next one suppressed.
    func testDecisionIsTakenPerUrlAndDoesNotLatch() {
        let delegate: StoriesCommunicationProtocol = SchemeAwareDelegate()

        XCTAssertFalse(delegate.shouldOpenLinkBySdk(url: "myshop://cart"))
        XCTAssertTrue(delegate.shouldOpenLinkBySdk(url: "https://example.com"))
        XCTAssertFalse(delegate.shouldOpenLinkBySdk(url: "myshop://product/1"))
        XCTAssertTrue(delegate.shouldOpenLinkBySdk(url: "https://example.com/other"))
    }
}
