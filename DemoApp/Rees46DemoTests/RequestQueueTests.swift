//
//  RequestQueueTests.swift
//  REES46Tests
//
//  Each shop sends through a queue of its own. A request made before the shop knows its device id
//  waits for `/init` and goes out with the id `/init` gave; another shop's requests do not wait.
//

import XCTest
@testable import REES46

final class RequestQueueTests: XCTestCase {

    private var shopIds: [String] = []
    private let initAnswer = DispatchSemaphore(value: 0)
    private var heldShop = ""

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        heldShop = StubSDK.shopId()
        shopIds = [heldShop]
        // `/init` of the held shop answers only when the test lets it.
        StubURLProtocol.handler = { [heldShop, initAnswer] request in
            guard request.path == "/init" else { return StubReply() }
            if request.query["shop_id"] == heldShop {
                _ = initAnswer.wait(timeout: .now() + 10)
                return StubReply(json: #"{"did":"fresh-did","seance":"s"}"#)
            }
            return StubReply(json: #"{"did":"other-did","seance":"s"}"#)
        }
    }

    override func tearDown() {
        initAnswer.signal()
        StubURLProtocol.uninstall()
        shopIds.forEach { StubSDK.removeSavedInit(shopId: $0) }
        super.tearDown()
    }

    private func initializedOtherShop() -> SimplePersonalizationSDK {
        let shopId = StubSDK.shopId()
        shopIds.append(shopId)
        let ready = expectation(description: "other shop init")
        let sdk = StubSDK.make(shopId: shopId) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        return sdk
    }

    func test_shops_send_through_queues_of_their_own() {
        let other = initializedOtherShop()
        let held = StubSDK.make(shopId: heldShop)

        XCTAssertFalse(held.sessionQueue === other.sessionQueue)
    }

    func test_an_event_sent_before_init_goes_out_with_the_device_id_from_init() {
        let held = StubSDK.make(shopId: heldShop)
        held.tracking.custom(event: "before-init")

        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/init").isEmpty })
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertTrue(StubURLProtocol.requests(to: "/push/custom").isEmpty, "the event left before /init answered")

        let answered = Date()
        initAnswer.signal()

        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/push/custom").isEmpty })
        guard let event = StubURLProtocol.requests(to: "/push/custom").first else { return }
        XCTAssertEqual(event.body["did"] as? String, "fresh-did")
        XCTAssertLessThan(event.time.timeIntervalSince(answered), 2, "the event waited a fixed pause instead of init")
    }

    func test_a_request_sent_before_init_goes_out_with_the_device_id_from_init() {
        let held = StubSDK.make(shopId: heldShop)
        held.recommend(blockId: "block-1") { _ in }

        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/init").isEmpty })
        Thread.sleep(forTimeInterval: 0.3)
        initAnswer.signal()

        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/recommend/block-1").isEmpty })
        XCTAssertEqual(StubURLProtocol.requests(to: "/recommend/block-1").first?.query["did"], "fresh-did")
    }

    func test_a_forced_reinitialization_does_not_send_requests_with_the_dropped_device_id() {
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "dropped-did"
        let held = StubSDK.make(shopId: heldShop, identity: identity, needReInitialization: true)
        held.recommend(blockId: "block-1") { _ in }

        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/init").isEmpty })
        Thread.sleep(forTimeInterval: 0.3)
        initAnswer.signal()

        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/recommend/block-1").isEmpty })
        XCTAssertNil(StubURLProtocol.requests(to: "/init").first?.query["did"])
        XCTAssertEqual(StubURLProtocol.requests(to: "/recommend/block-1").first?.query["did"], "fresh-did")
    }

    func test_a_shop_waiting_for_its_device_id_does_not_hold_another_shop() {
        let other = initializedOtherShop()
        let held = StubSDK.make(shopId: heldShop)
        held.tracking.custom(event: "before-init")
        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/init").filter { $0.query["shop_id"] == self.heldShop }.isEmpty })
        Thread.sleep(forTimeInterval: 0.3)

        let asked = Date()
        other.recommend(blockId: "block-2") { _ in }

        XCTAssertTrue(eventually(timeout: 8) { !StubURLProtocol.requests(to: "/recommend/block-2").isEmpty })
        guard let request = StubURLProtocol.requests(to: "/recommend/block-2").first else { return }
        XCTAssertLessThan(request.time.timeIntervalSince(asked), 2, "another shop's wait for its device id held this one")
    }
}
