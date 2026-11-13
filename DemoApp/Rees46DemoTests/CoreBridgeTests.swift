//
//  CoreBridgeTests.swift
//  REES46Tests
//
//  The API of the bridges (`@_spi(Bridge)`), as Flutter and React Native will call it: push events and
//  tokens beside the app's callbacks, the whole error behind an old one, an event through the queue
//  with the contract's result, the session's changes and the instance's own push callbacks.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class CoreBridgeTests: XCTestCase {

    private var shops: [String] = []
    private var clock = FakeClock()
    private var scheduler: ManualScheduler!
    private var lifecycle = ManualAppLifecycle()
    private var network = FakeConnectivity(online: true)
    private var deviceToken: Rees46.PushToken?

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        Rees46.reset()
        SdkRegistry.shared.reset()
        clock = FakeClock()
        scheduler = ManualScheduler(clock: clock)
        lifecycle = ManualAppLifecycle()
        network = FakeConnectivity(online: true)
        deviceToken = DeviceStore.shared.deviceToken
        let inits = Locked(0)
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply(json: #"{"status":"success"}"#) }
            var call = 0
            inits.mutate { $0 += 1; call = $0 }
            return StubReply(json: #"{"did":"d","seance":"s-\#(call)"}"#)
        }
    }

    override func tearDown() {
        Rees46.reset()
        SdkRegistry.shared.reset()
        StubURLProtocol.uninstall()
        CoreFlag.reset()
        DeviceStore.shared.deviceToken = deviceToken
        shops.forEach { StubSDK.removeSavedInit(shopId: $0) }
        shops.removeAll()
        super.tearDown()
    }

    private var environment: CoreEnvironment {
        CoreEnvironment(clock: clock, scheduler: scheduler, lifecycle: lifecycle, random: { 0.5 })
    }

    /// An instance with a known device inside its window, registered, its launch's `/init` heard.
    private func make(coreV2: Bool = true) -> SimplePersonalizationSDK {
        let shop = StubSDK.shopId()
        shops.append(shop)
        let known = InMemoryUserIdentityRepository()
        known.deviceId = "d"
        known.seance = "s-0"
        known.seanceLastActTime = clock.now()
        let sdk = StubSDK.make(shopId: shop, identity: known, connectivity: network, coreV2: coreV2, environment: environment)
        SdkRegistry.shared.register(shopId: shop, sdk: sdk)
        if coreV2 {
            XCTAssertTrue(eventually { sdk.settledInitCount >= 2 })
            sdk.eventQueue?.settle()
        } else {
            XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) >= 1 && sdk.state == .ready })
        }
        return sdk
    }

    private func push(_ shop: String, code: String = "m-1") -> [AnyHashable: Any] {
        ["shop_id": shop, "type": "bulk", "id": code, "title": "T", "body": "B", "event": #"{"type":"web","uri":"https://x"}"#]
    }

    // MARK: - Pushes and tokens

    func test_on_push_event_hears_every_event_with_the_whole_payload_beside_the_apps_callbacks() {
        let sdk = make()
        let heard = Locked<[(Rees46.PushEvent, Rees46.PushPayload, Bool)]>([])
        let app = Locked(0)
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onOpened: { _ in app.mutate { $0 += 1 } }))
        let subscription = Rees46.onPushEvent { event, payload in heard.mutate { $0.append((event, payload, Thread.isMainThread)) } }
        Rees46.handlePush(push(sdk.shopId), event: .opened)
        Rees46.handlePush(push(sdk.shopId), event: .opened)
        Rees46.handlePush(push(sdk.shopId), event: .closed)
        XCTAssertTrue(eventually { heard.current.count == 2 && app.current == 1 })
        XCTAssertEqual(heard.current.map { $0.0 }, [.opened, .closed], "once per event of a message")
        for (_, payload, main) in heard.current {
            XCTAssertTrue(main)
            XCTAssertEqual(payload.shopId, sdk.shopId)
            XCTAssertEqual(payload.title, "T")
            XCTAssertEqual(payload.body, "B")
            XCTAssertEqual(payload.target?.uri, "https://x")
            XCTAssertEqual(payload.data["id"], "m-1")
        }
        subscription.cancel()
        Rees46.handlePush(push(sdk.shopId, code: "m-2"), event: .clicked)
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/track/clicked", shop: sdk.shopId).count == 1 })
        XCTAssertEqual(heard.current.count, 2, "cancelled")
    }

    func test_on_push_token_hears_the_token_the_sdk_has_at_once_then_each_new_one_once() {
        let sdk = make()
        DeviceStore.shared.deviceToken = Rees46.PushToken(token: "known", provider: .apns)
        let heard = Locked<[Rees46.PushToken]>([])
        let subscription = Rees46.onPushToken { token in heard.mutate { $0.append(token) } }
        XCTAssertTrue(eventually { heard.current == [Rees46.PushToken(token: "known", provider: .apns)] })

        let service = NotificationService(sdk: sdk, notificationLogger: NotificationLogger())
        service.didReceiveRegistrationFCMToken(fcmToken: "fcm-1")
        service.didReceiveRegistrationFCMToken(fcmToken: "fcm-1")
        XCTAssertTrue(eventually { heard.current.count == 2 })
        XCTAssertEqual(heard.current.last, Rees46.PushToken(token: "fcm-1", provider: .fcm))
        subscription.cancel()
    }

    func test_the_instances_own_push_callbacks_through_the_bridge() {
        let sdk = make()
        let bridge: PersonalizationSDK = sdk
        let heard = Locked<[String]>([])
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { _ in heard.mutate { $0.append("facade") } }))
        bridge.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { _ in heard.mutate { $0.append("instance") } }))
        Rees46.handlePush(push(sdk.shopId), event: .delivered)
        XCTAssertTrue(eventually { heard.current == ["instance"] })
    }

    // MARK: - The whole error

    func test_bridge_errors_give_the_whole_error_behind_an_old_one_on_both_cores() {
        for coreV2 in [true, false] {
            let sdk = make(coreV2: coreV2)
            func product() -> Result<ProductInfo, Rees46.SdkError>? {
                let done = expectation(description: "products/get")
                let result = Locked<Result<ProductInfo, Rees46.SdkError>?>(nil)
                sdk.getProductInfo(id: "37", completion: Rees46.BridgeErrors.completion { result.current = $0; done.fulfill() })
                wait(for: [done], timeout: 5)
                return result.current
            }
            StubURLProtocol.handler = { $0.path == "/products/get" ? StubReply(404) : StubReply(json: #"{"did":"d","seance":"s-1"}"#) }
            guard case .failure(.http(code: 404, serverCode: nil))? = product() else { return XCTFail("404, coreV2 = \(coreV2)") }
            StubURLProtocol.handler = { $0.path == "/products/get" ? StubReply(503) : StubReply(json: #"{"did":"d","seance":"s-1"}"#) }
            guard case .failure(.http(code: 503, serverCode: nil))? = product() else { return XCTFail("503, coreV2 = \(coreV2)") }
            if coreV2 {
                // The old core's sessions wait for the network; the new core fails at once without it.
                network.isOnline = false
                guard case .failure(.network)? = product() else { return XCTFail("offline") }
                network.isOnline = true
            }
            sdk.release()
        }
        XCTAssertNil(Rees46.BridgeErrors.currentError(), "only while the SDK calls a completion")
    }

    func test_an_argument_the_sdk_refuses_reaches_the_bridge_as_invalid_argument() {
        let sdk = make()
        let done = expectation(description: "refused")
        let result = Locked<Result<Void, Rees46.SdkError>?>(nil)
        sdk.tracking.categoryView(categoryId: "", completion: Rees46.BridgeErrors.completion { result.current = $0; done.fulfill() })
        wait(for: [done], timeout: 5)
        guard case .failure(.invalidArgument)? = result.current else { return XCTFail("\(String(describing: result.current))") }

        let token = expectation(description: "token")
        let tokenResult = Locked<Result<Void, Rees46.SdkError>?>(nil)
        sdk.setPushTokenNotification(token: "", isFirebaseNotification: false, completion: Rees46.BridgeErrors.completion { tokenResult.current = $0; token.fulfill() })
        wait(for: [token], timeout: 5)
        guard case .failure(.invalidArgument)? = tokenResult.current else { return XCTFail("\(String(describing: tokenResult.current))") }
    }

    // MARK: - An event through the queue

    func test_queue_event_completes_on_the_main_thread_once_accepted() throws {
        let sdk = make()
        network.isOnline = false
        func queue(_ path: String, _ body: [String: Any], on instance: PersonalizationSDK) -> (Result<Void, Rees46.SdkError>, Bool)? {
            let done = expectation(description: path)
            let result = Locked<(Result<Void, Rees46.SdkError>, Bool)?>(nil)
            instance.queueEvent(path: path, body: body) { result.current = ($0, Thread.isMainThread); done.fulfill() }
            wait(for: [done], timeout: 5)
            return result.current
        }
        let accepted = queue("track/opened", ["code": "m-1", "type": "bulk"], on: sdk)
        guard case (.success, true)? = accepted else { return XCTFail("\(String(describing: accepted))") }
        let folder = try XCTUnwrap(sdk.storage.queueDirectory)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).count, 1, "accepted: on disk, not sent")
        XCTAssertTrue(StubURLProtocol.requests(to: "/track/opened", shop: sdk.shopId).isEmpty)

        guard case (.failure(.invalidArgument), _)? = queue("products/get", [:], on: sdk) else { return XCTFail("not an event") }
        guard case (.failure(.invalidArgument), _)? = queue("push", ["value": Double.nan], on: sdk) else { return XCTFail("not JSON") }
        network.isOnline = true
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/track/opened", shop: sdk.shopId).count == 1 })
        sdk.release()
        guard case (.failure(.notInitialized), _)? = queue("push", ["event": "view"], on: sdk) else { return XCTFail("released") }

        // The old core keeps no queue: the event goes at once and the bridge hears its answer.
        let legacy = make(coreV2: false)
        guard case (.success, true)? = queue("push", ["event": "view", "items": [["id": "37"]]], on: legacy) else { return XCTFail("sent") }
        XCTAssertEqual(StubURLProtocol.requests(to: "/push", shop: legacy.shopId).count, 1)
        XCTAssertEqual(StubURLProtocol.requests(to: "/push", shop: legacy.shopId).first?.body["did"] as? String, "d")
        StubURLProtocol.handler = { $0.path == "/push" ? StubReply(500) : StubReply() }
        guard case (.failure(.http(code: 500, serverCode: nil)), _)? = queue("push", ["event": "view"], on: legacy) else { return XCTFail("500") }
    }

    // MARK: - The session

    func test_on_session_change_through_the_bridge_hears_each_new_sid_on_the_main_thread() {
        let sdk = make()
        let bridge: PersonalizationSDK = sdk
        let heard = Locked<[(String, Bool)]>([])
        let subscription = bridge.onSessionChange { sid in heard.mutate { $0.append((sid, Thread.isMainThread)) } }
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { heard.current.count == 1 })
        XCTAssertEqual(heard.current.first?.0, "s-2")
        XCTAssertEqual(heard.current.first?.1, true)
        subscription.cancel()
        XCTAssertEqual(bridge.state, .ready)
        XCTAssertEqual(bridge.sessionId, "s-2")
    }
}
