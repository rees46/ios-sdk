//
//  CorePushTests.swift
//  REES46Tests
//
//  Pushes on the new core (`sdk/core/push.md`, `sdk/contract/notifications.md`, decision 0004) over the
//  stub server, with the clock, the scheduler, the network and the app's lifecycle in the test's hands:
//  the device's token and each shop's week, the events through the queue once per message, `received`
//  sent as `delivered`, a push in the active app as `opened`, the source of a click, the routing of
//  `handlePush` and the shop it returns, a pending shop's stored did, the callbacks and which win, the
//  parsed payload; and the old core sending what it always has.
//

import UIKit
import XCTest
@_spi(Bridge) @testable import REES46

final class CorePushTests: XCTestCase {

    private var shops: [String] = []
    private var clock = FakeClock()
    private var scheduler: ManualScheduler!
    private var lifecycle = ManualAppLifecycle()
    private var network = FakeConnectivity(online: true)
    private let replies = Locked<[String: [StubReply?]]>([:])
    private let logs = Locked<[Rees46.SdkLogMessage]>([])

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        Rees46.reset()
        SdkRegistry.shared.reset()
        clock = FakeClock()
        scheduler = ManualScheduler(clock: clock)
        lifecycle = ManualAppLifecycle()
        network = FakeConnectivity(online: true)
        replies.current = [:]
        logs.current = []
        let logs = self.logs
        Rees46.setLogHandler { message in logs.mutate { $0.append(message) } }
        let replies = self.replies
        let inits = Locked(0)
        StubURLProtocol.handler = { request in
            var reply: StubReply??
            replies.mutate { queued in
                guard var list = queued[request.path], !list.isEmpty else { return }
                reply = .some(list.count > 1 ? list.removeFirst() : list[0])
                queued[request.path] = list
            }
            if let reply = reply {
                return reply
            }
            if request.path == "/init" {
                var call = 0
                inits.mutate { $0 += 1; call = $0 }
                // The did it is sent stays; a device without one gets a new one.
                return StubReply(json: #"{"did":"\#(request.query["did"] ?? "d-\(call)")","seance":"s-\#(call)"}"#)
            }
            return StubReply(json: #"{"status":"success"}"#)
        }
    }

    override func tearDown() {
        Rees46.setLogHandler(nil)
        Rees46.reset()
        SdkRegistry.shared.reset()
        StubURLProtocol.uninstall()
        CoreFlag.reset()
        for shop in shops {
            StubSDK.removeSavedInit(shopId: shop)
            UserDefaults.standard.removePersistentDomain(forName: StoragePartition.suiteName(for: shop))
        }
        shops.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private var environment: CoreEnvironment {
        CoreEnvironment(clock: clock, scheduler: scheduler, lifecycle: lifecycle, random: { 0.5 })
    }

    private func newShop() -> String {
        let shop = StubSDK.shopId()
        shops.append(shop)
        return shop
    }

    private func answer(_ path: String, _ list: StubReply?...) {
        replies.mutate { $0[path] = list }
    }

    /// An instance of the new core with a known device inside its window, registered for `handlePush`,
    /// its launch's `/init` answered and heard.
    private func make(
        _ shop: String,
        identity: UserIdentityRepository? = nil,
        deviceStore: DeviceStore? = nil,
        coreV2: Bool = true,
        settled: Bool = true
    ) -> SimplePersonalizationSDK {
        let known = InMemoryUserIdentityRepository()
        known.deviceId = "d"
        known.seance = "s-0"
        known.seanceLastActTime = clock.now()
        let chosen = identity ?? known
        let sdk = StubSDK.make(
            shopId: shop, identity: chosen, logLevel: .debug, connectivity: network,
            coreV2: coreV2, environment: environment, deviceStore: deviceStore
        )
        SdkRegistry.shared.register(shopId: shop, sdk: sdk)
        if settled, coreV2 {
            let settles = (chosen.deviceId ?? "").isEmpty ? 1 : 2
            XCTAssertTrue(eventually { sdk.settledInitCount >= settles }, "the launch's /init answered")
            sdk.eventQueue?.settle()
        } else if settled {
            XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) >= 1 && sdk.state == .ready })
        }
        return sdk
    }

    private func requests(_ path: String, _ shop: String) -> [StubRequest] {
        StubURLProtocol.requests(to: path, shop: shop)
    }

    private func tokens(_ shop: String) -> [StubRequest] {
        requests("/mobile_push_tokens", shop)
    }

    private func logged(_ shop: String, _ code: String) -> [Rees46.SdkLogMessage] {
        logs.current.filter { $0.shopId == shop && $0.code == code }
    }

    private func files(_ sdk: SimplePersonalizationSDK) -> [String] {
        guard let folder = sdk.storage.queueDirectory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { $0.hasSuffix(".json") }
    }

    /// `setPushTokenNotification` and what it hears.
    private func send(_ sdk: SimplePersonalizationSDK, _ token: String, firebase: Bool = false) -> Result<Void, SdkError>? {
        let done = expectation(description: "token")
        let result = Locked<Result<Void, SdkError>?>(nil)
        sdk.setPushTokenNotification(token: token, isFirebaseNotification: firebase) { result.current = $0; done.fulfill() }
        wait(for: [done], timeout: 5)
        return result.current
    }

    private func push(_ shop: String?, type: String = "bulk", code: String = "m-1") -> [AnyHashable: Any] {
        var payload: [AnyHashable: Any] = [
            "type": type, "id": code, "title": "Sale", "body": "Today only",
            "event": #"{"type":"product","uri":"37"}"#,
        ]
        if let shop = shop {
            payload["shop_id"] = shop
        }
        return payload
    }

    // MARK: - The token

    func test_a_new_token_goes_at_once_with_its_platform_and_becomes_the_devices_token() {
        let shop = newShop()
        let sdk = make(shop)
        guard case .success? = send(sdk, "fcm-1", firebase: true) else { return XCTFail("sent") }

        XCTAssertEqual(tokens(shop).count, 1)
        let body = tokens(shop).first?.body ?? [:]
        XCTAssertEqual(body["token"] as? String, "fcm-1")
        XCTAssertEqual(body["platform"] as? String, "ios_firebase")
        XCTAssertEqual(body["did"] as? String, "d")
        XCTAssertEqual(body["shop_id"] as? String, shop)
        XCTAssertEqual(sdk.deviceStore.deviceToken, Rees46.PushToken(token: "fcm-1", provider: .fcm))
        XCTAssertTrue(eventually { !self.logged(shop, "push_token_sent").isEmpty })

        guard case .success? = send(sdk, "apns-1") else { return XCTFail("sent") }
        XCTAssertEqual(tokens(shop).last?.body["platform"] as? String, "ios")
    }

    func test_the_same_token_goes_at_most_once_a_week_per_shop_and_a_new_one_at_once() {
        let shop = newShop()
        let sdk = make(shop)
        guard case .success? = send(sdk, "t-1") else { return XCTFail("sent") }
        guard case .success? = send(sdk, "t-1") else { return XCTFail("a repeat within the week is a success") }
        XCTAssertEqual(tokens(shop).count, 1, "not again within the week")
        XCTAssertTrue(eventually { self.logged(shop, "push_token_skipped").last?.context["reason"] == "sent_recently" })

        guard case .success? = send(sdk, "t-2") else { return XCTFail("sent") }
        XCTAssertEqual(tokens(shop).map { $0.body["token"] as? String }, ["t-1", "t-2"], "a new token inside the week goes at once")

        clock.advance(by: PushTokenWeek.length)
        guard case .success? = send(sdk, "t-2") else { return XCTFail("sent") }
        XCTAssertTrue(eventually { self.tokens(shop).count == 3 }, "a week later it goes again")
        expectNoRequest(to: "/mobile_push_tokens", shop: shop, within: 0.3)
        XCTAssertEqual(tokens(shop).count, 3)
    }

    func test_the_week_is_claimed_before_the_request_so_two_sends_at_once_go_as_one() {
        let shop = newShop()
        let sdk = make(shop)
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/mobile_push_tokens" { _ = held.wait(timeout: .now() + 10) }
            return handler(request)
        }
        sdk.setPushTokenNotification(token: "t") { _ in }
        XCTAssertTrue(eventually { self.tokens(shop).count == 1 })
        guard case .success? = send(sdk, "t") else { return XCTFail("the second one is held back by the claim") }
        held.signal()
        expectNoRequest(to: "/mobile_push_tokens", shop: shop, within: 0.3)
        XCTAssertEqual(tokens(shop).count, 1)
    }

    func test_a_failed_send_gives_the_week_back() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/mobile_push_tokens", StubReply(500), StubReply(json: #"{"status":"success"}"#))
        guard case .failure? = send(sdk, "t") else { return XCTFail("failed") }
        XCTAssertTrue(eventually { !self.logged(shop, "push_token_failed").isEmpty })
        guard case .success? = send(sdk, "t") else { return XCTFail("sent") }
        XCTAssertEqual(tokens(shop).count, 2, "the failed one held nothing back")
    }

    func test_the_token_is_one_per_device_and_each_shop_sends_it_by_its_own_week() {
        let device = StubSDK.deviceStore(shopId: "device-\(UUID().uuidString.prefix(8))")
        let first = newShop()
        let second = newShop()
        let one = make(first, deviceStore: device)
        guard case .success? = send(one, "shared-token") else { return XCTFail("sent") }

        // Another shop of the app: its /init sends the device's token to its own server.
        _ = make(second, deviceStore: device)
        XCTAssertTrue(eventually { self.tokens(second).count == 1 })
        XCTAssertEqual(tokens(second).first?.body["token"] as? String, "shared-token")
        XCTAssertEqual(tokens(first).count, 1, "the first shop's week holds")
    }

    func test_the_apns_token_of_the_registrar_goes_as_ios_and_is_kept_where_the_old_core_reads_it() {
        let shop = newShop()
        let sdk = make(shop)
        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: Data([0xAB, 0x01]))
        XCTAssertTrue(eventually { self.tokens(shop).count == 1 })
        XCTAssertEqual(tokens(shop).first?.body["token"] as? String, "ab01")
        XCTAssertEqual(tokens(shop).first?.body["platform"] as? String, "ios")
        XCTAssertEqual(sdk.deviceStore.pushToken, Data([0xAB, 0x01]))
        XCTAssertEqual(sdk.deviceStore.deviceToken, Rees46.PushToken(token: "ab01", provider: .apns))
        XCTAssertNil(UserDefaults.standard.object(forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop)), "the old core's date is not used")
    }

    func test_the_token_never_goes_without_a_did_and_goes_once_the_first_init_brings_one() {
        let shop = newShop()
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/init" { _ = held.wait(timeout: .now() + 10) }
            return handler(request)
        }
        let sdk = make(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        let result = Locked<Result<Void, SdkError>?>(nil)
        expectNoRequest(to: "/mobile_push_tokens", shop: shop, within: 0.3) {
            result.current = self.send(sdk, "t")
        }
        guard case .failure(let error)? = result.current, error.isPushTokenWaitingForDeviceId else {
            return XCTFail("\(String(describing: result.current))")
        }
        XCTAssertTrue(eventually { self.logged(shop, "push_token_skipped").last?.context["reason"] == "no_device_id" })

        held.signal()
        XCTAssertTrue(eventually { self.tokens(shop).count == 1 })
        XCTAssertEqual(tokens(shop).first?.body["did"] as? String, "d-1")
        XCTAssertEqual(tokens(shop).first?.body["token"] as? String, "t")
    }

    func test_after_an_init_answer_the_devices_token_goes_when_its_week_allows() {
        let shop = newShop()
        let device = StubSDK.deviceStore(shopId: shop)
        device.deviceToken = Rees46.PushToken(token: "abcd", provider: .apns)
        let sdk = make(shop, deviceStore: device)
        XCTAssertTrue(eventually { self.tokens(shop).count == 1 })
        XCTAssertEqual(tokens(shop).first?.body["platform"] as? String, "ios")

        // A new session's /init: the week holds the token back.
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 2 && sdk.settledInitCount >= 3 })
        expectNoRequest(to: "/mobile_push_tokens", shop: shop, within: 0.3)
        XCTAssertTrue(eventually { self.logged(shop, "push_token_skipped").last?.context["reason"] == "sent_recently" })
    }

    func test_delete_user_credentials_forgets_the_week_and_the_next_did_gets_the_token() {
        let shop = newShop()
        let sdk = make(shop, identity: InMemoryUserIdentityRepository())
        guard case .success? = send(sdk, "t") else { return XCTFail("sent") }
        XCTAssertEqual(tokens(shop).first?.body["did"] as? String, "d-1")

        sdk.deleteUserCredentials()
        XCTAssertNil(sdk.storage.pushTokenSent)
        XCTAssertTrue(eventually { self.tokens(shop).count == 2 }, "the next customer gets the token")
        XCTAssertEqual(tokens(shop).last?.body["did"] as? String, "d-2")
        XCTAssertFalse(tokens(shop).contains { ($0.body["did"] as? String ?? "").isEmpty }, "never without a did")
    }

    func test_an_empty_token_is_an_invalid_argument() {
        let shop = newShop()
        let sdk = make(shop)
        let result = Locked<Result<Void, SdkError>?>(nil)
        expectNoRequest(to: "/mobile_push_tokens", shop: shop) { result.current = self.send(sdk, "") }
        guard case .failure(.custom)? = result.current else { return XCTFail("\(String(describing: result.current))") }
        XCTAssertTrue(eventually { !self.logged(shop, "invalid_argument").isEmpty })
    }

    func test_the_old_core_sends_every_token_it_is_given_as_before() {
        let shop = newShop()
        let sdk = make(shop, coreV2: false)
        guard case .success? = send(sdk, "t"), case .success? = send(sdk, "t") else { return XCTFail("sent") }
        XCTAssertEqual(tokens(shop).count, 2, "no week on setPushTokenNotification of the old core")
        XCTAssertNil(sdk.storage.pushTokenSent)
    }

    func test_set_push_token_after_release_is_not_initialized_and_writes_nothing() {
        let shop = newShop()
        let sdk = make(shop)
        sdk.release()
        let result = Locked<Result<Void, SdkError>?>(nil)
        expectNoRequest(to: "/mobile_push_tokens", shop: shop) { result.current = self.send(sdk, "t") }
        guard case .failure(.initializationFailed)? = result.current else { return XCTFail("\(String(describing: result.current))") }
        XCTAssertNil(sdk.deviceStore.deviceToken)
        XCTAssertNil(sdk.storage.pushTokenSent)
    }

    // MARK: - Events

    func test_handle_push_sends_each_event_through_the_queue_once_and_returns_the_shop() {
        let shop = newShop()
        _ = make(shop)
        for event in Rees46.PushEvent.allCases {
            XCTAssertEqual(Rees46.handlePush(push(shop), event: event), shop)
        }
        for event in Rees46.PushEvent.allCases {
            XCTAssertTrue(eventually { self.requests("/track/\(event.rawValue)", shop).count == 1 }, event.rawValue)
            let body = requests("/track/\(event.rawValue)", shop).first?.body ?? [:]
            XCTAssertEqual(body["code"] as? String, "m-1")
            XCTAssertEqual(body["type"] as? String, "bulk")
            XCTAssertEqual(body["did"] as? String, "d")
            XCTAssertEqual(body["shop_id"] as? String, shop)
            XCTAssertEqual(body["stream"] as? String, "ios")
            XCTAssertNil(body["sid"], "the server does not read it")
            XCTAssertNil(body["seance"])
            XCTAssertNil(body["source"])
        }

        // One event per message in the process: a repeat sends nothing and is still the shop's.
        expectNoRequest(to: "/track/clicked", shop: shop) {
            XCTAssertEqual(Rees46.handlePush(push(shop), event: .clicked), shop)
        }
        guard case .success? = { () -> Result<Void, SdkError>? in
            let done = expectation(description: "explicit")
            let result = Locked<Result<Void, SdkError>?>(nil)
            Rees46.handlePush(push(shop, code: "m-2"), event: .delivered)
            SdkRegistry.shared.byShopId(shop)?.notificationDelivered(type: "bulk", code: "m-2") { result.current = $0; done.fulfill() }
            wait(for: [done], timeout: 5)
            return result.current
        }() else { return XCTFail("a repeat is a success") }
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 2 }, "m-1 and m-2")
        expectNoRequest(to: "/track/delivered", shop: shop, within: 0.2)
        XCTAssertEqual(requests("/track/delivered", shop).count, 2, "once each")
        XCTAssertTrue(requests("/track/received", shop).isEmpty)
    }

    func test_a_push_in_the_background_two_hours_after_the_last_event_starts_no_session() {
        let shop = newShop()
        let sdk = make(shop)
        lifecycle.send(.didEnterBackground)
        clock.advance(by: 2 * 60 * 60 + 1)
        expectNoRequest(to: "/init", shop: shop, within: 0.5) {
            Rees46.handlePush(push(shop), event: .delivered)
        }
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 }, "a stored did is all it needs")
        XCTAssertNil(requests("/track/delivered", shop).first?.body["sid"])
        XCTAssertNil(sdk.sessionId, "no session started or revived")
    }

    func test_a_push_event_the_queue_does_not_take_is_not_counted_as_sent() {
        let shop = newShop()
        let first = make(shop)
        first.release()
        let refused = expectation(description: "refused")
        first.notificationDelivered(type: "bulk", code: "m-1") { result in
            if case .failure(.initializationFailed) = result { refused.fulfill() }
        }
        wait(for: [refused], timeout: 5)

        // The next instance of the shop sends it: the released one's call claimed nothing.
        _ = make(shop)
        Rees46.handlePush(push(shop), event: .delivered)
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 })
    }

    func test_push_events_wait_in_the_queue_offline_and_go_when_the_network_comes_back() {
        let shop = newShop()
        let sdk = make(shop)
        network.isOnline = false
        Rees46.handlePush(push(shop), event: .delivered)
        sdk.eventQueue?.settle()
        XCTAssertEqual(files(sdk).count, 1, "on disk")
        XCTAssertTrue(requests("/track/delivered", shop).isEmpty)
        network.isOnline = true
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 })
        XCTAssertTrue(eventually { self.files(sdk).isEmpty })
    }

    func test_received_of_the_old_api_is_delivered_once_on_the_new_core_and_never_track_received() {
        let shop = newShop()
        _ = make(shop)
        expectNoRequest(to: "/track/received", shop: shop, within: 0.5) {
            Rees46.handlePush(push(shop), event: PushEvent.delivered)
            Rees46.handlePush(push(shop), event: PushEvent.received)
            Rees46.handlePush(push(shop, code: "m-2"), event: PushEvent.received)
        }
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 2 })
        XCTAssertEqual(requests("/track/delivered", shop).map { $0.body["code"] as? String }, ["m-1", "m-2"])
    }

    func test_a_click_stores_the_push_as_the_source_of_the_next_push_events_for_48_hours() {
        let shop = newShop()
        let sdk = make(shop)
        Rees46.handlePush(push(shop, type: "chain", code: "c-7"), event: .clicked)
        XCTAssertTrue(eventually { self.requests("/track/clicked", shop).count == 1 })
        XCTAssertEqual(sdk.sourceStore.currentSource()?.type, "chain")
        XCTAssertEqual(sdk.sourceStore.currentSource()?.code, "c-7")
        XCTAssertNil(requests("/track/clicked", shop).first?.body["source"])

        sdk.tracking.productView(itemId: "37")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        XCTAssertEqual(requests("/push", shop).first?.body["source"] as? [String: String], ["from": "chain", "code": "c-7"])
        XCTAssertNil(requests("/push", shop).first?.body["from"], "no top-level from and code")

        // A type that is not a source changes nothing.
        Rees46.handlePush(push(shop, type: "digest", code: "dg-1"), event: .clicked)
        XCTAssertTrue(eventually { self.requests("/track/clicked", shop).count == 2 })
        XCTAssertEqual(sdk.sourceStore.currentSource()?.code, "c-7")
    }

    func test_the_old_tracking_methods_of_pushes_go_through_the_queue_once_and_call_no_callback() {
        let shop = newShop()
        let sdk = make(shop)
        let heard = Locked(0)
        Rees46.setPushCallbacks(Rees46.PushCallbacks(
            onDelivered: { _ in heard.mutate { $0 += 1 } },
            onClicked: { _ in heard.mutate { $0 += 1 } }
        ))
        func call(_ body: (@escaping (Result<Void, SdkError>) -> Void) -> Void) -> Result<Void, SdkError>? {
            let done = expectation(description: "call")
            let result = Locked<Result<Void, SdkError>?>(nil)
            body { result.current = $0; done.fulfill() }
            wait(for: [done], timeout: 5)
            return result.current
        }
        guard case .success? = call({ sdk.notificationDelivered(type: "bulk", code: "x-1", completion: $0) }) else { return XCTFail("sent") }
        XCTAssertEqual(requests("/track/delivered", shop).count, 1, "heard once it went")
        guard case .success? = call({ sdk.notificationReceived(type: "bulk", code: "x-1", completion: $0) }) else { return XCTFail("a repeat") }
        guard case .success? = call({ sdk.notificationClicked(type: "chain", code: "x-1", completion: $0) }) else { return XCTFail("sent") }
        XCTAssertEqual(requests("/track/clicked", shop).count, 1)
        XCTAssertEqual(sdk.sourceStore.currentSource()?.code, "x-1", "a click stores the source")
        guard case .failure(.custom)? = call({ sdk.notificationClicked(type: "", code: "x-2", completion: $0) }) else { return XCTFail("empty type") }
        XCTAssertEqual(requests("/track/delivered", shop).count, 1)
        XCTAssertTrue(requests("/track/received", shop).isEmpty)
        expectNoRequest(to: "/track/clicked", shop: shop, within: 0.2)
        XCTAssertEqual(heard.current, 0, "the app knows of the event")
    }

    func test_a_push_in_the_active_app_is_opened_on_the_new_core_and_a_background_one_delivered_once() {
        let shop = newShop()
        let sdk = make(shop)
        let service = NotificationService(sdk: sdk, notificationLogger: NotificationLogger())
        service.handleArrival(push(shop), state: .active)
        XCTAssertTrue(eventually { self.requests("/track/opened", shop).count == 1 })
        XCTAssertTrue(requests("/track/clicked", shop).isEmpty, "nobody tapped it")

        Rees46.handlePush(push(shop, code: "m-2"), event: .delivered)
        expectNoRequest(to: "/track/received", shop: shop) {
            service.handleArrival(self.push(shop, code: "m-2"), state: .background)
        }
        XCTAssertEqual(requests("/track/delivered", shop).count, 1)
    }

    func test_a_pending_shop_sends_by_its_stored_did_without_init_and_never_without_one() {
        CoreFlag.reset(to: true)
        let shop = newShop()
        let empty = newShop()
        StoragePartition.store(for: shop).set("pending-did", forKey: StoragePartition.deviceIdKey)
        Rees46.register(shops: [
            Rees46Config(shopId: shop, apiDomain: "stub.test", coreV2: true),
            Rees46Config(shopId: empty, apiDomain: "stub.test", coreV2: true),
        ])

        XCTAssertEqual(Rees46.handlePush(push(shop, type: "chain", code: "p-1"), event: .clicked), shop)
        XCTAssertTrue(eventually { self.requests("/track/clicked", shop).count == 1 })
        let body = requests("/track/clicked", shop).first?.body ?? [:]
        XCTAssertEqual(body["did"] as? String, "pending-did")
        XCTAssertEqual(body["code"] as? String, "p-1")
        XCTAssertEqual(body["type"] as? String, "chain")
        XCTAssertNil(body["sid"])
        XCTAssertTrue(requests("/init", shop).isEmpty, "no /init for it")
        XCTAssertTrue(Rees46.pendingShopIds().contains(shop), "not created")
        XCTAssertEqual(TrackingSourceStoreImpl(store: StoragePartition.store(for: shop)).currentSource()?.code, "p-1")

        expectNoRequest(to: "/track/clicked", shop: shop) {
            Rees46.handlePush(self.push(shop, type: "chain", code: "p-1"), event: .clicked)
        }
        Rees46.handlePush(push(shop, code: "p-2"), event: PushEvent.received)
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 })

        // A shop that never had a device id here: nothing goes.
        expectNoRequest(to: "/track/delivered", shop: empty) {
            XCTAssertEqual(Rees46.handlePush(self.push(empty), event: .delivered), empty)
        }
        XCTAssertTrue(eventually { self.logs.current.contains { $0.code == "push_dropped" && $0.context["reason"] == "no_did" } })
    }

    func test_a_push_that_is_not_the_sdks_or_names_no_known_shop_returns_nothing() {
        let first = newShop()
        let second = newShop()
        _ = make(first)
        XCTAssertNil(Rees46.handlePush(["title": "Hi"], event: .delivered))
        XCTAssertNil(Rees46.handlePush(push("unknown-shop"), event: .delivered))
        XCTAssertEqual(Rees46.handlePush(push(nil), event: .delivered), first, "the one shop takes a push without shop_id")
        _ = make(second)
        XCTAssertNil(Rees46.handlePush(push(nil, code: "m-9"), event: .delivered), "several shops: not guessed")
        XCTAssertTrue(eventually { self.logs.current.contains { $0.code == "push_dropped" && $0.context["reason"] == "ambiguous_shop" } })
    }

    // MARK: - Callbacks

    func test_the_callback_of_each_event_gets_the_parsed_push_on_the_main_thread_once() {
        let shop = newShop()
        _ = make(shop)
        let heard = Locked<[(String, Rees46.PushPayload, Bool)]>([])
        func record(_ name: String) -> (Rees46.PushPayload) -> Void {
            { payload in heard.mutate { $0.append((name, payload, Thread.isMainThread)) } }
        }
        Rees46.setPushCallbacks(Rees46.PushCallbacks(
            onDelivered: record("delivered"), onOpened: record("opened"), onClicked: record("clicked"), onClosed: record("closed")
        ))
        for event in Rees46.PushEvent.allCases {
            Rees46.handlePush(push(nil), event: event)
            Rees46.handlePush(push(nil), event: event)
        }
        XCTAssertTrue(eventually { heard.current.count == 4 })
        expectNoRequest(to: "/track/closed", shop: shop, within: 0.2)
        XCTAssertEqual(heard.current.map { $0.0 }, ["delivered", "opened", "clicked", "closed"], "once each")
        for (_, payload, main) in heard.current {
            XCTAssertTrue(main)
            XCTAssertEqual(payload.shopId, shop, "the shop it went to")
            XCTAssertEqual(payload.code, "m-1")
            XCTAssertEqual(payload.type, "bulk")
            XCTAssertEqual(payload.title, "Sale")
            XCTAssertEqual(payload.target?.type, .product)
            XCTAssertEqual(payload.target?.uri, "37")
        }
    }

    func test_the_callbacks_and_the_bridges_hear_only_an_event_the_queue_accepted() {
        let shop = newShop()
        let released = make(shop)
        released.release()
        // Still routed to, as a push that comes while the app swaps its instance: the queue takes nothing.
        SdkRegistry.shared.register(shopId: shop, sdk: released)
        let heard = Locked<[String]>([])
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { _ in heard.mutate { $0.append("app") } }))
        let bridge = Rees46.onPushEvent { _, _ in heard.mutate { $0.append("bridge") } }
        defer { bridge.cancel() }

        XCTAssertEqual(Rees46.handlePush(push(shop), event: .delivered), shop)
        // The queue's refusal frees the event: nothing was told for it, and it may go again.
        XCTAssertTrue(eventually { !PushCenter.isTaken(.delivered, code: "m-1", shopId: shop) })
        drainMainQueue()
        XCTAssertTrue(heard.current.isEmpty, "a refused event calls no callback and tells no bridge")

        SdkRegistry.shared.reset()
        _ = make(shop)
        Rees46.handlePush(push(shop), event: .delivered)
        XCTAssertTrue(eventually { heard.current.sorted() == ["app", "bridge"] }, "accepted now: heard once")
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 })
    }

    func test_an_instances_own_callbacks_win_over_the_facades_one_by_one() {
        let shop = newShop()
        let sdk = make(shop)
        let heard = Locked<[String]>([])
        Rees46.setPushCallbacks(Rees46.PushCallbacks(
            onDelivered: { _ in heard.mutate { $0.append("facade delivered") } },
            onClicked: { _ in heard.mutate { $0.append("facade clicked") } }
        ))
        sdk.setPushCallbacks(Rees46.PushCallbacks(onClicked: { _ in heard.mutate { $0.append("instance clicked") } }))
        Rees46.handlePush(push(shop), event: .clicked)
        Rees46.handlePush(push(shop), event: .delivered)
        XCTAssertTrue(eventually { heard.current.count == 2 })
        XCTAssertEqual(heard.current, ["instance clicked", "facade delivered"])

        sdk.setPushCallbacks(nil)
        Rees46.handlePush(push(shop, code: "m-2"), event: .clicked)
        XCTAssertTrue(eventually { heard.current.last == "facade clicked" })
    }

    func test_on_token_hears_each_token_the_service_gets_once_and_every_shop_takes_it() {
        let first = newShop()
        let second = newShop()
        let device = StubSDK.deviceStore(shopId: first)
        let one = make(first, deviceStore: device)
        _ = make(second, deviceStore: device)
        let heard = Locked<[Rees46.PushToken]>([])
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onToken: { token in heard.mutate { $0.append(token) } }))
        let service = NotificationService(sdk: one, notificationLogger: NotificationLogger())

        service.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data([0x0A, 0x0B]))
        service.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data([0x0A, 0x0B]))
        service.didReceiveRegistrationFCMToken(fcmToken: "fcm-9")
        XCTAssertTrue(eventually { heard.current.count == 2 })
        XCTAssertEqual(heard.current, [Rees46.PushToken(token: "0a0b", provider: .apns), Rees46.PushToken(token: "fcm-9", provider: .fcm)])
        XCTAssertTrue(eventually { self.tokens(first).count == 2 && self.tokens(second).count == 2 }, "each shop sends the device's tokens")
    }

    func test_a_pending_shops_push_calls_the_facades_callback() {
        CoreFlag.reset(to: true)
        let shop = newShop()
        StoragePartition.store(for: shop).set("pending-did", forKey: StoragePartition.deviceIdKey)
        Rees46.register(shops: [Rees46Config(shopId: shop, apiDomain: "stub.test", coreV2: true)])
        let heard = Locked<[String]>([])
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { payload in heard.mutate { $0.append(payload.shopId) } }))
        Rees46.handlePush(push(shop), event: .delivered)
        XCTAssertTrue(eventually { heard.current == [shop] })
    }

    // MARK: - The old core

    func test_the_old_core_sends_its_events_as_before_and_calls_the_callbacks() {
        let shop = newShop()
        _ = make(shop, coreV2: false)
        let heard = Locked(0)
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { _ in heard.mutate { $0 += 1 } }))
        XCTAssertEqual(Rees46.handlePush(push(shop), event: .delivered), shop)
        Rees46.handlePush(push(shop), event: .delivered)
        Rees46.handlePush(push(shop), event: PushEvent.received)
        expectNoRequest(to: "/track/opened", shop: shop) {
            Rees46.handlePush(self.push(shop), event: .opened)
            Rees46.handlePush(self.push(shop), event: .closed)
        }
        XCTAssertTrue(requests("/track/closed", shop).isEmpty, "the old core keeps exactly its events")
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 2 }, "no once-per-message rule on the old core")
        XCTAssertTrue(eventually { self.requests("/track/received", shop).count == 1 })
        XCTAssertTrue(eventually { heard.current == 2 })
    }

    // MARK: - The payload

    func test_the_payload_of_an_fcm_push() {
        let fcm: [AnyHashable: Any] = [
            "shop_id": "s", "id": "m1", "type": "bulk", "title": "T", "body": "B", "icon": "https://i",
            "image": "https://img", "source": "utm", "ios_sound_file": "ding.caf",
            "actions": #"[{"action":"a1","title":"Open"},{"action":"a2","title":"Later"}]"#,
            "action_urls": #"["https://a1"]"#,
            "event": #"{"type":"product","uri":"37","payload":{"k":"v"}}"#,
        ]
        let payload = Rees46.PushPayload.parse(fcm, shopId: "s")
        XCTAssertEqual(payload?.code, "m1")
        XCTAssertEqual(payload?.type, "bulk")
        XCTAssertEqual(payload?.title, "T")
        XCTAssertEqual(payload?.body, "B")
        XCTAssertEqual(payload?.icon, "https://i")
        XCTAssertEqual(payload?.image, "https://img")
        XCTAssertEqual(payload?.actions, [
            Rees46.PushAction(id: "a1", title: "Open", url: "https://a1"),
            Rees46.PushAction(id: "a2", title: "Later", url: nil),
        ])
        XCTAssertEqual(payload?.target?.type, .product)
        XCTAssertEqual(payload?.target?.uri, "37")
        XCTAssertEqual(payload?.target?.payload["k"] as? String, "v")
        XCTAssertEqual(payload?.source, "utm")
        XCTAssertEqual(payload?.sound, "ding.caf")
        XCTAssertEqual(payload?.data["id"], "m1")
    }

    func test_the_payload_of_an_apns_push() throws {
        let json = """
        {"shop_id":"s","src":{"type":"chain","id":"m2"},"event":{"type":"web","uri":"https://x"},\
        "aps":{"alert":{"title":"AT","body":"AB"}},"image_url":"https://img"}
        """
        let apns = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [AnyHashable: Any])
        let payload = Rees46.PushPayload.parse(apns, shopId: "s")
        XCTAssertEqual(payload?.code, "m2")
        XCTAssertEqual(payload?.type, "chain", "the mailing's type, not what it opens")
        XCTAssertEqual(payload?.title, "AT")
        XCTAssertEqual(payload?.body, "AB")
        XCTAssertEqual(payload?.image, "https://img")
        XCTAssertEqual(payload?.actions, [])
        XCTAssertEqual(payload?.target?.type, .web)
        XCTAssertEqual(payload?.target?.type.rawValue, "web")
        XCTAssertNotNil(payload?.data["src"], "an object written as JSON")
        XCTAssertNil(Rees46.PushPayload.parse(["title": "x"], shopId: "s"), "not a push of the SDK")
    }
}
