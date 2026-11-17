//
//  LegacyParityTests.swift
//  REES46Tests
//
//  The old core (an app's `Rees46.initialize`) behaves as 3.37.3 did, but for the fixes named for both
//  cores: a repeated `initialize` after a failed `/init` or with `needReInitialization`, the request
//  queue the app sees while `/init` is on its way and the order its requests leave in, the push token it
//  reads, `enableLogs`, the tracking and push wire, the decoding rules, the error types of `/init`, the
//  arrival of a push and the pending shop's push through the real tracker.
//

import UIKit
import XCTest
@_spi(Bridge) @testable import REES46

final class LegacyParityTests: CoreScenarioTestCase {

    override func setUp() {
        super.setUp()
        CoreFlag.reset(to: false)
    }

    // MARK: - LEG-H8: a repeated initialize

    func test_a_repeated_initialize_after_a_failed_init_makes_a_new_instance_with_a_new_init() throws {
        let shop = newShop()
        answer("/init", StubReply(500), StubReply(json: #"{"did":"d2"}"#))
        let config = Rees46Config(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false)
        let failed = expectation(description: "first")
        let firstError = Locked<SdkError?>(nil)
        let first = Rees46.initialize(config) { firstError.current = $0; failed.fulfill() }
        wait(for: [failed], timeout: 10)
        XCTAssertNotNil(firstError.current, "the first /init failed")
        XCTAssertEqual(first.state, .initializing)

        // As in 3.37.3: the app's next initialize sends a new /init.
        let done = expectation(description: "second")
        let second = Rees46.initialize(config) { error in
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        XCTAssertFalse(same(first, second), "a new instance")
        XCTAssertEqual(inits(shop).count, 2)
        XCTAssertEqual(second.deviceId, "d2")
        XCTAssertTrue(same(try Rees46.instance(for: shop), second), "it replaces the shop's registration")
        XCTAssertNotEqual(first.state, .notInitialized, "the first goes on for whoever holds it")
        first.release()
        second.release()
    }

    func test_a_repeated_initialize_with_need_re_initialization_makes_a_new_instance_with_a_new_did() throws {
        let shop = newShop()
        let ready = expectation(description: "first")
        let first = Rees46.initialize(Rees46Config(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false)) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 10)
        XCTAssertEqual(first.deviceId, "d-1")

        let done = expectation(description: "second")
        let second = Rees46.initialize(Rees46Config(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false, needReInitialization: true)) { _ in
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        XCTAssertFalse(same(first, second))
        XCTAssertNil(inits(shop).last?.query["did"], "the stored did was dropped")
        XCTAssertEqual(second.deviceId, "d-2", "a new device id")
        XCTAssertTrue(logged(shop, "invalid_config").isEmpty, "not an ignored configuration")
        first.release()
        second.release()
    }

    func test_a_repeated_initialize_of_a_ready_shop_or_on_the_new_core_returns_the_instance() {
        let shop = newShop()
        let ready = expectation(description: "first")
        let config = Rees46Config(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false)
        let first = Rees46.initialize(config) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 10)
        XCTAssertTrue(same(Rees46.initialize(config), first), "ready: the same instance")
        first.release()

        CoreFlag.reset(to: true)
        let v2 = newShop()
        answer("/init", StubReply(500))
        let v2Config = Rees46Config(shopId: v2, apiDomain: "stub.test", autoSendPushToken: false)
        let made = Rees46.initializeBridge(v2Config)
        XCTAssertTrue(same(Rees46.initializeBridge(v2Config), made), "the new core repeats its /init itself")
        XCTAssertTrue(same(Rees46.initializeBridge(Rees46Config(shopId: v2, apiDomain: "stub.test", autoSendPushToken: false, needReInitialization: true)), made))
        made.release()
    }

    func test_create_personalization_sdk_twice_makes_two_instances_and_the_second_is_the_shops() {
        let shop = newShop()
        let ready = expectation(description: "both")
        ready.expectedFulfillmentCount = 2
        let first = createPersonalizationSDK(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false) { _ in ready.fulfill() }
        let second = createPersonalizationSDK(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false, needReInitialization: true) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 10)
        XCTAssertFalse(same(first, second))
        XCTAssertTrue(same(SdkRegistry.shared.byShopId(shop), second))
        XCTAssertNotEqual(first.state, .notInitialized, "the first is not released")
        XCTAssertNil(inits(shop).last?.query["did"])

        // A push for the shop reaches the second.
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 })
        XCTAssertEqual(requests("/track/delivered", shop).first?.body["did"] as? String, second.deviceId)
        first.release()
        second.release()
    }

    // MARK: - LEG-M8: the request queue while /init is on its way

    func test_requests_waiting_for_init_are_in_the_public_session_queue_and_cancel_all_cancels_them() {
        let shop = newShop()
        hold("/init")
        let sdk = makeLegacy(shop, settled: false)
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })
        let heard = Locked(0)
        sdk.recommend(blockId: "b") { _ in heard.mutate { $0 += 1 } }
        XCTAssertGreaterThanOrEqual(sdk.sessionQueue.operationCount, 1, "the app sees the waiting request")

        sdk.sessionQueue.cancelAll()
        release("/init")
        XCTAssertTrue(eventually { sdk.state == .ready })
        XCTAssertTrue(eventually { sdk.sessionQueue.operationCount == 0 })
        sdk.sessionQueue.waitUntilAllOperationsAreFinished()
        XCTAssertTrue(requests("/recommend/b", shop).isEmpty, "a cancelled request never goes, as in 3.37.3")
        XCTAssertEqual(heard.current, 0)
        sdk.release()
    }

    func test_an_operation_the_app_adds_before_init_answers_waits_for_it() {
        let shop = newShop()
        hold("/init")
        let sdk = makeLegacy(shop, settled: false)
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })
        let ran = Locked<Int?>(nil)
        let done = expectation(description: "the app's operation")
        sdk.sessionQueue.addOperation(BlockOperation {
            ran.current = StubURLProtocol.answered(to: "/init", shop: shop)
            done.fulfill()
        })
        XCTAssertNil(ran.current)
        release("/init")
        wait(for: [done], timeout: 10)
        XCTAssertEqual(ran.current, 1, "it ran once /init answered")
        sdk.release()
    }

    func test_requests_waiting_for_init_go_after_the_apps_init_completion() {
        let shop = newShop()
        hold("/init")
        let completed = Locked(false)
        let wentAfterCompletion = Locked<Bool?>(nil)
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/recommend/b" { wentAfterCompletion.current = completed.current }
            return handler(request)
        }
        let sdk = makeLegacy(shop, settled: false) { _ in completed.current = true }
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })
        sdk.recommend(blockId: "b") { _ in }
        release("/init")
        XCTAssertTrue(eventually { wentAfterCompletion.current != nil })
        XCTAssertEqual(wentAfterCompletion.current, true, "as in 3.37.3, the init completion runs first")
        XCTAssertEqual(requests("/recommend/b", shop).first?.query["did"], "d-1")
        sdk.release()
    }

    // MARK: - LEG-H3: a failed first /init still lets the waiting requests go

    func test_requests_waiting_for_a_first_init_that_fails_still_complete() {
        for reply in [StubReply(503), StubReply(402)] {
            let shop = newShop()
            hold("/init")
            answer("/init", reply)
            let sdk = makeLegacy(shop, settled: false)
            XCTAssertTrue(eventually { self.inits(shop).count == 1 })
            let done = expectation(description: "both")
            done.expectedFulfillmentCount = 2
            sdk.recommend(blockId: "b") { _ in done.fulfill() }
            sdk.tracking.productView(itemId: "1") { _ in done.fulfill() }
            release("/init")
            wait(for: [done], timeout: 10)
            XCTAssertEqual(requests("/recommend/b", shop).first?.query["did"], "", "\(reply.status): without a did, as before")
            XCTAssertEqual(sdk.state, .initializing)
            XCTAssertFalse((sdk.sessionQueue as? ShopSessionQueue)?.isClosed ?? true)
            sdk.release()
        }
    }

    func test_release_while_requests_wait_for_init_ends_them_once_and_sends_none() {
        let shop = newShop()
        hold("/init")
        let sdk = makeLegacy(shop, settled: false)
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })
        let results = Locked<[Result<RecommenderResponse, SdkError>]>([])
        let done = expectation(description: "recommend")
        sdk.recommend(blockId: "b") { result in results.mutate { $0.append(result) }; done.fulfill() }
        sdk.release()
        wait(for: [done], timeout: 10)
        release("/init")
        sdk.sessionQueue.waitUntilAllOperationsAreFinished()
        XCTAssertTrue(requests("/recommend/b", shop).isEmpty)
        XCTAssertEqual(results.current.count, 1)
        guard case .failure(.initializationFailed)? = results.current.first else { return XCTFail("\(results.current)") }
    }

    // MARK: - The push token the old core reads

    func test_the_old_core_sends_the_apns_token_where_3_37_3_kept_it() {
        let shop = newShop()
        let device = UserDefaults(suiteName: "test-device-\(shop)")!
        let standardLike = UserDefaults(suiteName: "test-standard-\(shop)")!
        defer {
            UserDefaults.standard.removePersistentDomain(forName: "test-device-\(shop)")
            UserDefaults.standard.removePersistentDomain(forName: "test-standard-\(shop)")
        }
        // A downgrade to 3.37.3 got a new token, which it kept only where it always did.
        device.set(Data([0x0A]), forKey: DeviceStore.pushTokenKey)
        standardLike.set(Data([0x0B]), forKey: SdkConstants.deviceToken)
        let store = DeviceStore(defaults: device, pushTokenDefaults: standardLike)
        XCTAssertEqual(store.legacyPushToken, Data([0x0B]))

        let ready = expectation(description: "init")
        let sdk = SimplePersonalizationSDK(
            shopId: shop, apiDomain: "stub.test", autoSendPushToken: true, enableAutoPopupPresentation: false,
            userIdentity: InMemoryUserIdentityRepository(), keychainStore: InMemoryKeychainInitStore(),
            localState: LocalStateRepositoryImpl(store: UserDefaults(suiteName: "test-\(shop)")!),
            connectivity: network, deviceStore: store
        ) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 10)
        XCTAssertTrue(eventually { !self.requests("/mobile_push_tokens", shop).isEmpty })
        XCTAssertEqual(requests("/mobile_push_tokens", shop).first?.body["token"] as? String, "0b", "the token 3.37.3 got last")
        sdk.release()
    }

    // MARK: - enableLogs as it was given

    @available(*, deprecated)
    func test_enable_logs_is_what_the_app_gave() {
        XCTAssertTrue(Rees46Config(shopId: "a", enableLogs: true).enableLogs)
        XCTAssertFalse(Rees46Config(shopId: "a").enableLogs)
        XCTAssertTrue(Rees46Config(shopId: "a", enableLogs: true, logLevel: .error).enableLogs)
        XCTAssertFalse(Rees46Config(shopId: "a", enableLogs: false, logLevel: .debug).enableLogs)
        XCTAssertEqual(Rees46Config(shopId: "a", enableLogs: true).logLevel, .debug)
    }

    // MARK: - handlePush as a function value

    func test_handle_push_is_still_usable_as_a_function_value() {
        let shop = newShop()
        _ = makeLegacy(shop)
        // Taken as a value without a type, it is the overload of `Rees46.PushEvent`; a call with
        // `.delivered` reads as before.
        let handle = Rees46.handlePush
        _ = handle(pushPayload(shop), .delivered)
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 })
    }

    // MARK: - Q-H3 / LEG-H1: the tracking wire of 3.37.3

    func test_the_old_cores_tracking_wire_is_3_37_3s() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let done = expectation(description: "sent")
        done.expectedFulfillmentCount = 5
        sdk.tracking.syncCart(items: [TrackingItem(id: "sku-1", quantity: 2, price: 10)]) { _ in done.fulfill() }
        sdk.tracking.syncFavorites(itemIds: ["a"]) { _ in done.fulfill() }
        sdk.tracking.storyView(storyId: "12", slideId: "34", code: "main") { _ in done.fulfill() }
        sdk.track(event: .synchronizeCart(items: [CartItem(productId: "sku-2", quantity: 3, price: 5)]), recommendedBy: nil) { _ in done.fulfill() }
        sdk.track(event: .productAddedToCart(id: "1", amount: 2), recommendedBy: nil) { _ in done.fulfill() }
        wait(for: [done], timeout: 10)

        let pushes = requests("/push", shop).map(\.body)
        let cart = pushes.first { ($0["items"] as? [[String: Any]])?.first?["id"] as? String == "sku-1" } ?? [:]
        let cartItem = (cart["items"] as? [[String: Any]])?.first ?? [:]
        XCTAssertNotNil(cartItem["amount"] as? String, "amount is a String: \(String(describing: cartItem["amount"]))")
        XCTAssertEqual(cartItem["amount"] as? String, "2")
        XCTAssertNotNil(cart["full_cart"] as? String, "full_cart is a String")
        XCTAssertEqual(cart["full_cart"] as? String, "true")
        let deprecated = pushes.first { ($0["items"] as? [[String: Any]])?.first?["id"] as? String == "sku-2" } ?? [:]
        XCTAssertEqual(((deprecated["items"] as? [[String: Any]])?.first?["amount"]) as? String, "3")
        let wish = pushes.first { $0["full_wish"] != nil } ?? [:]
        XCTAssertNotNil(wish["full_wish"] as? String)
        XCTAssertEqual(wish["full_wish"] as? String, "true")
        let added = pushes.first { ($0["items"] as? [[String: Any]])?.first?["id"] as? String == "1" } ?? [:]
        XCTAssertEqual(((added["items"] as? [[String: Any]])?.first?["amount"]) as? Int, 2)
        let story = requests("/track/stories", shop).first?.body ?? [:]
        XCTAssertNotNil(story["story_id"] as? String, "story_id is a String")
        XCTAssertEqual(story["story_id"] as? String, "12")
        XCTAssertEqual(story["slide_id"] as? String, "34")
    }

    // MARK: - NET-H1 / LEG-M4: the old core keeps no argument rules of the new one

    func test_the_old_core_sends_empty_ids_and_virtual_slides_as_3_37_3_did() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let done = expectation(description: "all")
        done.expectedFulfillmentCount = 5
        let results = Locked<[Result<Void, SdkError>]>([])
        let record: (Result<Void, SdkError>) -> Void = { result in results.mutate { $0.append(result) }; done.fulfill() }
        sdk.tracking.productView(itemId: "", completion: record)
        sdk.tracking.categoryView(categoryId: " ", completion: record)
        sdk.tracking.search(query: "", completion: record)
        sdk.tracking.storyView(storyId: "12_3", slideId: "5", code: "main", completion: record)
        sdk.tracking.storyClick(storyId: "12", slideId: "12_0", code: "main", completion: record)
        wait(for: [done], timeout: 10)
        for result in results.current {
            guard case .success = result else { return XCTFail("\(result)") }
        }
        let pushes = requests("/push", shop).map(\.body)
        XCTAssertTrue(pushes.contains { (($0["items"] as? [[String: Any]])?.first?["id"]) as? String == "" })
        XCTAssertTrue(pushes.contains { $0["category_id"] as? String == " " })
        XCTAssertTrue(pushes.contains { $0["search_query"] as? String == "" })
        let stories = requests("/track/stories", shop).map(\.body)
        XCTAssertTrue(stories.contains { $0["story_id"] as? String == "12_3" })
        XCTAssertTrue(stories.contains { $0["slide_id"] as? String == "12_0" })
        XCTAssertTrue(logged(shop, "invalid_argument").isEmpty)
    }

    // MARK: - NET-H3 / LEG-H2: the decoding rules of 3.37.3

    func test_the_old_cores_decoding_rules_are_3_37_3s() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        answer("/track/clicked", StubReply(204, json: ""))
        answer("/track/delivered", StubReply(204, json: ""))
        answer("/track/received", StubReply(204, json: ""))
        answer("/popup/showed", StubReply(204, json: ""))
        answer("/push", StubReply(204, json: ""), StubReply(200, json: "[1]"))
        answer("/products/get", StubReply(200, json: ""), StubReply(200, json: "<html>"), StubReply(200, json: "[1]"))
        answer("/profile/set", StubReply(400, json: #"{"status":"error"}"#))

        func call(_ body: (@escaping (Result<Void, SdkError>) -> Void) -> Void) -> Result<Void, SdkError>? {
            let done = expectation(description: "call")
            let outcome = Locked<Result<Void, SdkError>?>(nil)
            body { outcome.current = $0; done.fulfill() }
            wait(for: [done], timeout: 10)
            return outcome.current
        }
        // An empty 2xx is a success for clicked, received and showed; for delivered and /push it is not.
        guard case .success? = call({ sdk.notificationClicked(type: "bulk", code: "c", completion: $0) }) else { return XCTFail("clicked") }
        guard case .success? = call({ sdk.notificationReceived(type: "bulk", code: "c", completion: $0) }) else { return XCTFail("received") }
        guard case .success? = call({ sdk.trackPopupShown(popupId: 7, completion: $0) }) else { return XCTFail("showed") }
        guard case .failure(.decodeError)? = call({ sdk.notificationDelivered(type: "bulk", code: "c", completion: $0) }) else { return XCTFail("delivered") }
        guard case .failure(.decodeError)? = call({ sdk.tracking.productView(itemId: "1", completion: $0) }) else { return XCTFail("push empty") }
        guard case .failure(.decodeError)? = call({ sdk.tracking.productView(itemId: "2", completion: $0) }) else { return XCTFail("push array") }
        for name in ["empty", "html", "array"] {
            guard case .failure(.decodeError)? = getProduct(sdk) else { return XCTFail("products/get \(name)") }
        }
        let posted = expectation(description: "profile/set")
        let profile = Locked<Result<[String: Any], SdkError>?>(nil)
        sdk.postRequest(path: "profile/set", params: ["email": "a@b.c"]) { profile.current = $0; posted.fulfill() }
        wait(for: [posted], timeout: 10)
        guard case .failure(.invalidResponse)? = profile.current else { return XCTFail("a 400 without a message: \(String(describing: profile.current))") }
    }

    // MARK: - LEG-H6 / INIT-N21: the error types and the thread of the init completion

    func test_the_init_completion_of_the_old_core_has_3_37_3s_errors_off_the_main_thread() {
        let cases: [(StubReply?, Bool, SdkError)] = [
            (StubReply(402), true, .invalidResponse),
            (StubReply(500), false, .invalidResponse),
            (StubReply(200, json: "not json"), false, .decodeError),
        ]
        for (reply, saved, expected) in cases {
            let shop = newShop()
            answer("/init", reply)
            let keychain = InMemoryKeychainInitStore(saved ? Data(#"{"did":"saved-did"}"#.utf8) : nil)
            let onMain = Locked<Bool?>(nil)
            let error = Locked<SdkError?>(nil)
            let sdk = makeLegacy(shop, keychain: keychain) { failure in
                onMain.current = Thread.isMainThread
                error.current = failure
            }
            XCTAssertEqual(onMain.current, false, "\(expected): the URL session's thread, as in 3.37.3")
            XCTAssertEqual(error.current?.logKind, expected.logKind, "\(String(describing: error.current))")
            sdk.release()
        }
    }

    // MARK: - LEG-H5: stream and the headers

    func test_the_old_core_sends_its_stream_and_json_headers() {
        let shop = newShop()
        let ready = expectation(description: "init")
        let sdk = SimplePersonalizationSDK(
            shopId: shop, apiDomain: "stub.test", stream: "flutter", autoSendPushToken: false, enableAutoPopupPresentation: false,
            userIdentity: InMemoryUserIdentityRepository(), keychainStore: InMemoryKeychainInitStore(),
            localState: LocalStateRepositoryImpl(store: UserDefaults(suiteName: "test-\(shop)")!), connectivity: network,
            deviceStore: StubSDK.deviceStore(shopId: shop)
        ) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 10)
        _ = getProduct(sdk)
        let posted = expectation(description: "posts")
        posted.expectedFulfillmentCount = 2
        sdk.postRequest(path: "push", params: ["event": "view", "shop_id": shop]) { _ in posted.fulfill() }
        sdk.postRequest(path: "push/custom", params: ["event": "e", "shop_id": shop, "stream": "custom"]) { _ in posted.fulfill() }
        wait(for: [posted], timeout: 10)
        XCTAssertEqual(requests("/products/get", shop).first?.query["stream"], "flutter")
        let push = requests("/push", shop).first
        XCTAssertEqual(push?.body["stream"] as? String, "flutter")
        XCTAssertEqual(push?.header("Content-Type"), "application/json")
        XCTAssertEqual(push?.header("Accept"), "application/json")
        XCTAssertEqual(requests("/push/custom", shop).first?.body["stream"] as? String, "custom", "the caller's wins")
        sdk.release()
    }

    // MARK: - PUSH-H1 / PUSH-H4: a push's arrival on the old core

    func test_the_arrival_of_a_push_sends_what_3_37_3_sent_on_the_old_core() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let service = NotificationService(sdk: sdk, notificationLogger: NotificationLogger())
        let opened = Locked(0)
        let closed = Locked(0)
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onOpened: { _ in opened.mutate { $0 += 1 } }, onClosed: { _ in closed.mutate { $0 += 1 } }))

        // In the background, twice: delivered and received every time — no dedup on the old core.
        for _ in 0..<2 {
            Rees46.handlePush(pushPayload(shop), event: .delivered)
            service.handleArrival(pushPayload(shop), state: .background)
        }
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 2 && self.requests("/track/received", shop).count == 2 })
        // In the active app: delivered only. Tapped: clicked.
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        service.handleArrival(pushPayload(shop), state: .active)
        service.handleArrival(pushPayload(shop), state: .inactive)
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 3 && self.requests("/track/clicked", shop).count == 1 })

        // The events it never had call only the callbacks.
        Rees46.handlePush(pushPayload(shop), event: .opened)
        Rees46.handlePush(pushPayload(shop), event: .closed)
        XCTAssertTrue(eventually { opened.current == 1 && closed.current == 1 })
        // Everything the instance sends goes through its queue: once it is idle, nothing more comes.
        sdk.sessionQueue.waitUntilAllOperationsAreFinished()
        XCTAssertTrue(requests("/track/opened", shop).isEmpty)
        XCTAssertTrue(requests("/track/closed", shop).isEmpty)
        XCTAssertEqual(requests("/track/clicked", shop).count, 1)
        sdk.release()
    }

    func test_the_push_events_of_the_old_core_carry_what_3_37_3_sent() {
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "d"
        let sdk = makeLegacy(shop, identity: identity)
        let done = expectation(description: "sent")
        done.expectedFulfillmentCount = 3
        sdk.notificationDelivered(type: "bulk", code: "m-1") { _ in done.fulfill() }
        sdk.notificationReceived(type: "bulk", code: "m-1") { _ in done.fulfill() }
        sdk.notificationClicked(type: "bulk", code: "m-1") { _ in done.fulfill() }
        wait(for: [done], timeout: 10)
        for path in ["/track/delivered", "/track/received", "/track/clicked"] {
            let request = requests(path, shop).first
            XCTAssertEqual(request?.method, "POST", path)
            XCTAssertEqual(Set(request?.body.keys.map { $0 } ?? []), ["stream", "shop_id", "did", "code", "type"], path)
            XCTAssertEqual(request?.body["did"] as? String, "d")
            XCTAssertEqual(request?.header("Content-Type"), "application/json")
        }
        answer("/track/clicked", StubReply(404, json: #"{"status":"error","message":"x"}"#))
        let failed = expectation(description: "404")
        let outcome = Locked<Result<Void, SdkError>?>(nil)
        sdk.notificationClicked(type: "bulk", code: "m-2") { outcome.current = $0; failed.fulfill() }
        wait(for: [failed], timeout: 10)
        guard case .failure(.custom("x"))? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
        sdk.release()
    }

    // MARK: - PUSH-H3 / LEG-H7: a pending shop's push through the real tracker

    func test_a_pending_shops_push_goes_through_the_real_tracker_on_the_old_core() {
        let (shop, _) = registerPending(did: nil, coreV2: false)
        Rees46.handlePush(pushPayload(shop), event: PushEvent.received)
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop), event: .delivered), shop)
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop), event: .clicked), shop)
        Rees46.handlePush(pushPayload(shop), event: .opened)
        Rees46.handlePush(pushPayload(shop), event: .closed)
        XCTAssertTrue(eventually {
            ["/track/received", "/track/delivered", "/track/clicked"].allSatisfy { StubURLProtocol.answered(to: $0, shop: shop) == 1 }
        })
        for path in ["/track/received", "/track/delivered", "/track/clicked"] {
            let request = requests(path, shop).first
            XCTAssertEqual(request?.url?.host, "stub.test")
            XCTAssertEqual(request?.body["did"] as? String, "", "\(path): no did stored, sent as before")
            XCTAssertEqual(request?.body["stream"] as? String, "ios")
            XCTAssertEqual(Set(request?.body.keys.map { $0 } ?? []), ["stream", "shop_id", "did", "code", "type"])
            XCTAssertNil(request?.header("Cookie"))
        }
        XCTAssertTrue(requests("/track/opened", shop).isEmpty)
        XCTAssertTrue(requests("/track/closed", shop).isEmpty)
        XCTAssertNil(SdkRegistry.shared.byShopId(shop), "no instance made")

        StoragePartition.store(for: shop).set("lazy", forKey: StoragePartition.deviceIdKey)
        Rees46.handlePush(pushPayload(shop, code: "m-2"), event: .delivered)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 2 })
        XCTAssertEqual(requests("/track/delivered", shop).last?.body["did"] as? String, "lazy")
    }

    func test_a_pending_shop_with_a_storage_key_finds_the_did_its_old_suite_kept() {
        let suite = "appkey-\(UUID().uuidString.prefix(6))"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        UserDefaults(suiteName: suite)?.set("old-did", forKey: StoragePartition.deviceIdKey)
        let (shop, _) = registerPending(did: nil, coreV2: false, storageKey: suite)
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 1 })
        XCTAssertEqual(requests("/track/delivered", shop).first?.body["did"] as? String, "old-did")
    }

    // MARK: - LEG-M3, LEG-M9, LEG-M10, INIT-L5

    func test_the_old_core_sends_a_trimmed_fashion_size_and_omits_a_blank_one() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let done = expectation(description: "both")
        done.expectedFulfillmentCount = 2
        sdk.tracking.addToCart(item: TrackingItem(id: "37", quantity: 2, price: 999.5, fashionSize: " M ")) { _ in done.fulfill() }
        sdk.tracking.addToCart(item: TrackingItem(id: "38", quantity: 1, fashionSize: "  ")) { _ in done.fulfill() }
        wait(for: [done], timeout: 10)
        let items = requests("/push", shop).compactMap { ($0.body["items"] as? [[String: Any]])?.first }
        XCTAssertEqual(items.first { $0["id"] as? String == "37" }?["fashion_size"] as? String, "M")
        XCTAssertNil(items.first { $0["id"] as? String == "38" }?["fashion_size"])
    }

    func test_the_old_cores_session_stays_for_the_instance_lifetime() {
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "d"
        identity.seance = "old-sid"
        identity.seanceLastActTime = Date().addingTimeInterval(-(2 * 60 * 60 - 60))
        let sdk = makeLegacy(shop, identity: identity)
        let sid = sdk.userSeance
        XCTAssertEqual(sid, "old-sid", "inside its window")
        _ = getProduct(sdk)
        XCTAssertEqual(sdk.userSeance, sid)
        XCTAssertEqual(sdk.sessionId, sid)
        sdk.release()
    }

    func test_a_get_offline_on_the_old_core_is_offline_and_logged_so() {
        let shop = newShop()
        let offline = FakeConnectivity(online: true)
        let sdk = makeLegacy(shop, connectivity: offline)
        offline.isOnline = false
        answer("/products/get", StubReply.noAnswer)
        guard case .failure(.networkOfflineError)? = getProduct(sdk) else { return XCTFail("offline") }
        XCTAssertTrue(eventually { self.logged(shop, "request_failed").contains { $0.context["reason"] == "offline" } })
        sdk.release()
    }

    func test_an_init_answer_without_a_did_keeps_the_stored_one_on_the_old_core() {
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "kept"
        answer("/init", StubReply(json: "{}"))
        let sdk = makeLegacy(shop, identity: identity)
        XCTAssertEqual(sdk.deviceId, "kept")
        _ = getProduct(sdk)
        XCTAssertEqual(requests("/products/get", shop).first?.query["did"], "kept")
        sdk.release()
    }

    // MARK: - NET-H2: the app's own URLSession object

    func test_the_old_core_sends_through_the_apps_very_session_and_its_delegate() {
        final class Recorder: NSObject, URLSessionTaskDelegate {
            let paths = Locked<[String]>([])
            func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
                paths.mutate { $0.append(task.originalRequest?.url?.path ?? "") }
            }
        }
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let recorder = Recorder()
        let session = URLSession(configuration: .default, delegate: recorder, delegateQueue: nil)
        sdk.urlSession = session
        XCTAssertTrue(sdk.urlSession === session)
        guard case .success? = getProduct(sdk) else { return XCTFail("products/get") }
        XCTAssertTrue(eventually { recorder.paths.current.contains("/products/get") }, "its delegate (pinning, say) applies")
        XCTAssertTrue(logged(shop, "invalid_config").isEmpty)
        XCTAssertNil(requests("/products/get", shop).last?.header("Cookie"))
        sdk.release()
    }

    // MARK: - S-H2: an upgrade with a storageKey that names no app group

    func test_an_upgrade_with_a_storage_key_keeps_the_session_the_ab_group_and_the_advertising_id() throws {
        let shop = newShop()
        let key = "k-\(UUID().uuidString.prefix(6))"
        let suite = try XCTUnwrap(UserDefaults(suiteName: key))
        let partitionName = StoragePartition.suiteName(for: shop, storageKey: key)
        defer {
            UserDefaults.standard.removePersistentDomain(forName: key)
            UserDefaults.standard.removePersistentDomain(forName: partitionName)
            ShopStorage(shopId: shop, storageKey: key, logger: SdkLogger(shopId: shop, level: .none)).directory.map { try? FileManager.default.removeItem(at: $0) }
        }
        // 3.37.3's layout: the suite named by storageKey was the shop's whole storage.
        suite.set("d", forKey: StoragePartition.deviceIdKey)
        suite.set("S", forKey: StoragePartition.seanceKey)
        suite.set(Date().timeIntervalSince1970 - 60, forKey: StoragePartition.seanceLastActKey)
        suite.set("B", forKey: StoragePartition.abSegmentKey)
        suite.set("idfa-1", forKey: StoragePartition.idfaKey)
        let before = UserDefaults.standard.persistentDomain(forName: key)

        let ready = expectation(description: "init")
        let sdk = SimplePersonalizationSDK(
            shopId: shop, apiDomain: "stub.test", autoSendPushToken: false, enableAutoPopupPresentation: false,
            storageKey: key, keychainStore: InMemoryKeychainInitStore(), connectivity: network
        ) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 10)
        let initRequest = inits(shop).first
        XCTAssertEqual(initRequest?.query["did"], "d")
        XCTAssertEqual(initRequest?.query["sid"], "S", "the session goes on")
        XCTAssertEqual(initRequest?.query["ios_advertising_id"], "idfa-1")
        XCTAssertEqual(sdk.segment, "B", "the A/B group goes on")
        let partition = try XCTUnwrap(UserDefaults(suiteName: partitionName))
        XCTAssertEqual(partition.string(forKey: StoragePartition.idfaKey), "idfa-1")
        XCTAssertEqual(UserDefaults.standard.persistentDomain(forName: key) as NSDictionary?, before as NSDictionary?, "the old suite is left as it was")
        sdk.release()
    }

    // MARK: - S-H3: an app group's storageKey, both cores

    func test_an_app_groups_storage_key_is_the_shared_partition_on_both_cores() throws {
        for coreV2 in [false, true] {
            CoreFlag.reset(to: coreV2)
            let group = "group.test.\(UUID().uuidString.prefix(6))"
            let suite = try XCTUnwrap(UserDefaults(suiteName: group))
            defer { UserDefaults.standard.removePersistentDomain(forName: group) }
            suite.set("G", forKey: StoragePartition.deviceIdKey)
            suite.set("S", forKey: StoragePartition.seanceKey)
            suite.set(Date().timeIntervalSince1970 - 60, forKey: StoragePartition.seanceLastActKey)
            suite.set("A", forKey: StoragePartition.abSegmentKey)
            let first = newShop()
            let second = newShop()
            func launch(_ shop: String) -> SimplePersonalizationSDK {
                let ready = expectation(description: "init of \(shop)")
                let sdk = SimplePersonalizationSDK(
                    shopId: shop, apiDomain: "stub.test", autoSendPushToken: false, enableAutoPopupPresentation: false,
                    storageKey: group, coreV2: coreV2, keychainStore: InMemoryKeychainInitStore(), connectivity: network
                ) { _ in ready.fulfill() }
                XCTAssertEqual(sdk.usesCoreV2, coreV2)
                wait(for: [ready], timeout: 10)
                return sdk
            }
            let a = launch(first)
            // The new core is ready at once on the stored did: its /init is on its way.
            XCTAssertTrue(eventually { !self.inits(first).isEmpty })
            XCTAssertEqual(inits(first).first?.query["did"], "G", "coreV2 = \(coreV2)")
            XCTAssertEqual(inits(first).first?.query["sid"], "S")
            XCTAssertEqual(a.segment, "A")
            XCTAssertNil(UserDefaults.standard.persistentDomain(forName: "\(group)_personalization_sdk_\(first)"), "the group's suite is the partition")
            XCTAssertTrue(StorageMigrations.isDone(.storageKeySuite, in: suite, scope: StoragePartition.keyScope(shopId: first, storageKey: group)))
            XCTAssertNotNil(suite.object(forKey: "personalization_sdk.migrated.storage_key_suite.\(StoragePartition.sanitize(first))"), "the flag carries the shop")
            XCTAssertEqual(a.storage.directory?.lastPathComponent, StoragePartition.folderName(for: first, storageKey: group), "a folder of its own")
            let b = launch(second)
            XCTAssertTrue(eventually { !self.inits(second).isEmpty })
            XCTAssertEqual(inits(second).first?.query["did"], "G", "shared, as before")
            a.release()
            b.release()
            for shop in [first, second] {
                ShopStorage(shopId: shop, storageKey: group, logger: SdkLogger(shopId: shop, level: .none)).directory.map { try? FileManager.default.removeItem(at: $0) }
            }
        }
    }

    // MARK: - S-M8: sendIDFARequest twice on the old core

    func test_send_idfa_request_keeps_the_first_answer_on_file_and_the_last_in_the_keychain() {
        let shop = newShop()
        let keychain = InMemoryKeychainInitStore()
        let sdk = makeLegacy(shop, keychain: keychain)
        XCTAssertNil(sdk.storage.readSavedInitAnswer(), "the old core's /init saves nothing; sendIDFARequest does")
        answer("/init", StubReply(json: #"{"did":"d-1","n":1}"#), StubReply(json: #"{"did":"d-1","n":2}"#))
        for _ in 0..<2 {
            let done = expectation(description: "idfa")
            sdk.sendIDFARequest(idfa: UUID()) { _ in done.fulfill() }
            wait(for: [done], timeout: 10)
        }
        XCTAssertEqual(keychain.data, Data(#"{"did":"d-1","n":2}"#.utf8), "the keychain the last")
        XCTAssertEqual(sdk.storage.readSavedInitAnswer(), Data(#"{"did":"d-1","n":1}"#.utf8), "the file the first")
        XCTAssertFalse(FileManager.default.fileExists(atPath: StubSDK.savedInitFile(shopId: shop).path), "not in Documents any more")
        sdk.release()
    }

    // MARK: - LEG-M6 / S-L13: the contacts are not sent again after deleteUserCredentials

    @available(*, deprecated)
    func test_the_contacts_given_at_creation_go_once_and_not_for_the_next_customer() {
        let shop = newShop()
        let ready = expectation(description: "init")
        let sdk = createPersonalizationSDK(shopId: shop, userEmail: "a@b.c", apiDomain: "stub.test", autoSendPushToken: false) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 10)
        XCTAssertTrue(eventually { self.requests("/profile/set", shop).count == 1 })

        sdk.deleteUserCredentials()
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 2 && sdk.state == .ready })
        sdk.sessionQueue.waitUntilAllOperationsAreFinished()
        _ = getProduct(sdk)
        XCTAssertEqual(requests("/profile/set", shop).count, 1, "not for the new did")
        sdk.release()
    }

    // MARK: - PUSH-M10: a push routed to a released instance with no next one

    func test_a_push_routed_to_a_released_instance_goes_on_its_stored_did_through_the_tracker() {
        let shop = newShop()
        let old = makeLegacy(shop)
        StoragePartition.store(for: shop).set("stored", forKey: StoragePartition.deviceIdKey)
        old.release()
        let launches = inits(shop).count
        Rees46.deliver(.event(.delivered), type: "bulk", code: "m-1", payload: pushPayload(shop), to: old, shopId: shop)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 1 })
        XCTAssertEqual(requests("/track/delivered", shop).first?.body["did"] as? String, "stored")
        XCTAssertNil(SdkRegistry.shared.byShopId(shop), "no instance made")
        XCTAssertEqual(inits(shop).count, launches, "no /init")
    }

    // MARK: - NET-M7: the bridges' errors of a timeout and a bad answer, both cores

    func test_the_bridges_hear_timeout_and_decoding_on_both_cores() {
        for coreV2 in [false, true] {
            let shop = newShop()
            let sdk: SimplePersonalizationSDK = coreV2 ? makeV2(shop) : makeLegacy(shop)
            XCTAssertEqual(sdk.usesCoreV2, coreV2)
            answer("/recommend/b", StubReply(json: "{}", delay: 2))
            let late = expectation(description: "timeout")
            let timedOut = Locked<Result<RecommenderResponse, Rees46.SdkError>?>(nil)
            sdk.recommend(blockId: "b", timeOut: 0.3, completion: Rees46.BridgeErrors.completion { timedOut.current = $0; late.fulfill() })
            wait(for: [late], timeout: 10)
            guard case .failure(.timeout)? = timedOut.current else { return XCTFail("coreV2 = \(coreV2): \(String(describing: timedOut.current))") }

            answer("/products/get", StubReply(json: "not json"))
            let bad = expectation(description: "decoding")
            let decoded = Locked<Result<ProductInfo, Rees46.SdkError>?>(nil)
            sdk.getProductInfo(id: "1", completion: Rees46.BridgeErrors.completion { decoded.current = $0; bad.fulfill() })
            wait(for: [bad], timeout: 10)
            guard case .failure(.decoding)? = decoded.current else { return XCTFail("coreV2 = \(coreV2): \(String(describing: decoded.current))") }
            sdk.release()
            answer("/recommend/b")
            answer("/products/get")
        }
    }

    // MARK: - PUSH-M7: the bridges' API on the old core

    func test_the_bridges_hear_the_pushes_and_the_token_answers_of_the_old_core() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let events = Locked<[(Rees46.PushEvent, Bool)]>([])
        let listener = Rees46.onPushEvent { event, _ in events.mutate { $0.append((event, Thread.isMainThread)) } }
        defer { listener.cancel() }
        for event in [Rees46.PushEvent.delivered, .clicked, .opened, .closed] {
            Rees46.handlePush(pushPayload(shop, code: "m-\(event.rawValue)"), event: event)
        }
        XCTAssertTrue(eventually { events.current.count == 4 })
        XCTAssertEqual(events.current.map { $0.0 }, [.delivered, .clicked, .opened, .closed])
        XCTAssertTrue(events.current.allSatisfy { $0.1 }, "on the main thread")
        sdk.sessionQueue.waitUntilAllOperationsAreFinished()
        XCTAssertTrue(requests("/track/opened", shop).isEmpty)

        let results = Locked<[Result<Void, Rees46.SdkError>]>([])
        let first = expectation(description: "sent")
        sdk.setPushToken(Rees46.PushToken(token: "t", provider: .apns)) { result in results.mutate { $0.append(result) }; first.fulfill() }
        wait(for: [first], timeout: 10)
        XCTAssertEqual(requests("/mobile_push_tokens", shop).first?.body["platform"] as? String, "ios")
        answer("/mobile_push_tokens", StubReply(500))
        let second = expectation(description: "failed")
        sdk.setPushToken(Rees46.PushToken(token: "t2", provider: .apns)) { result in results.mutate { $0.append(result) }; second.fulfill() }
        wait(for: [second], timeout: 10)
        guard results.current.count == 2, case .success = results.current[0], case .failure(.http(code: 500, _)) = results.current[1] else {
            return XCTFail("\(results.current)")
        }
        sdk.release()
    }

    // MARK: - LEG-L1: the old core's listeners on the main thread

    func test_the_old_cores_state_listener_flush_and_push_callback_run_on_the_main_thread() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let threads = Locked<[String: Bool]>([:])
        let all = expectation(description: "all")
        all.expectedFulfillmentCount = 3
        let handle = sdk.onStateChange { _ in
            var first = false
            threads.mutate { first = $0["state"] == nil; $0["state"] = Thread.isMainThread }
            if first { all.fulfill() }
        }
        sdk.flush { _ in threads.mutate { $0["flush"] = Thread.isMainThread }; all.fulfill() }
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { _ in threads.mutate { $0["push"] = Thread.isMainThread }; all.fulfill() }))
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        wait(for: [all], timeout: 10)
        XCTAssertEqual(threads.current, ["state": true, "flush": true, "push": true])
        handle.cancel()
        sdk.release()
    }

    // MARK: - LEG-L3 / LEG-L4: an empty FCM token and a plus in a query

    func test_an_empty_fcm_token_goes_as_it_did_and_a_plus_in_a_query_is_sent_as_it_was() {
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "d"
        let sdk = makeLegacy(shop, identity: identity)
        let service = NotificationService(sdk: sdk, notificationLogger: NotificationLogger())
        service.didReceiveRegistrationFCMToken(fcmToken: nil)
        XCTAssertTrue(eventually { self.requests("/mobile_push_tokens", shop).count == 1 })
        XCTAssertEqual(requests("/mobile_push_tokens", shop).first?.body["token"] as? String, "", "as in 3.37.3")
        XCTAssertEqual(requests("/mobile_push_tokens", shop).first?.body["platform"] as? String, "ios_firebase")

        let done = expectation(description: "search")
        sdk.search(query: "a+b") { _ in done.fulfill() }
        wait(for: [done], timeout: 10)
        let url = requests("/search", shop).first?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("a+b"), url)
        XCTAssertFalse(url.contains("a%2Bb"), "the old core leaves a plus as it is")
        sdk.release()
    }

    // MARK: - INIT-L6 / INIT-L7: the old core's /init

    func test_the_old_cores_init_sends_a_stored_advertising_id_and_never_the_zero_one() {
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.advertisingId = "idfa-1"
        let sdk = makeLegacy(shop, identity: identity)
        XCTAssertEqual(inits(shop).first?.query["ios_advertising_id"], "idfa-1", "without sendAdvertisingId, as in 3.37.3")
        sdk.release()

        let zero = newShop()
        let zeroIdentity = InMemoryUserIdentityRepository()
        zeroIdentity.advertisingId = "00000000-0000-0000-0000-000000000000"
        let other = makeLegacy(zero, identity: zeroIdentity)
        XCTAssertNil(inits(zero).first?.query["ios_advertising_id"])
        other.release()
    }

    func test_the_old_cores_init_logs_a_refusal_as_an_error_a_server_error_as_a_warning_and_a_stand_in() {
        let refusing = newShop()
        answer("/init", StubReply(402))
        let a = makeLegacy(refusing)
        XCTAssertTrue(eventually { self.logged(refusing, "init_failed").first?.level == .error })
        a.release()

        let failing = newShop()
        answer("/init", StubReply(500))
        let b = makeLegacy(failing)
        XCTAssertTrue(eventually { self.logged(failing, "init_failed").first?.level == .warning })
        b.release()

        let standing = newShop()
        answer("/init", StubReply.noAnswer)
        let c = makeLegacy(standing, keychain: InMemoryKeychainInitStore(Data(#"{"did":"saved"}"#.utf8)))
        XCTAssertTrue(waitForLog(standing, "init_saved_answer"))
        c.release()

        let passing = newShop()
        answer("/init")
        let d = makeLegacy(passing)
        XCTAssertTrue(eventually { self.logged(passing, "init_succeeded").first?.level == .info })
        d.release()
    }
}

