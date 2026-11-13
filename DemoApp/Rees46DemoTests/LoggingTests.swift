//
//  LoggingTests.swift
//  REES46Tests
//
//  The SDK's log: levels, the app's handler, and what never gets into a message.
//

import XCTest
@testable import REES46

final class LoggingTests: XCTestCase {

    private var shopId = ""
    private let lock = NSLock()
    private var received: [Rees46.SdkLogMessage] = []

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        shopId = StubSDK.shopId()
        received = []
        Rees46.setLogHandler { [weak self] message in
            guard let self = self else { return }
            self.lock.lock(); self.received.append(message); self.lock.unlock()
        }
    }

    override func tearDown() {
        Rees46.setLogHandler(nil)
        StubURLProtocol.uninstall()
        StubSDK.removeSavedInit(shopId: shopId)
        super.tearDown()
    }

    private var messages: [Rees46.SdkLogMessage] {
        lock.lock(); defer { lock.unlock() }
        return received
    }

    private func messages(of shop: String) -> [Rees46.SdkLogMessage] {
        messages.filter { $0.shopId == shop }
    }

    func test_a_level_lets_through_itself_and_what_is_above() {
        let logger = SdkLogger(shopId: "levels-\(shopId)", level: .warning)
        logger.debug("d", "debug")
        logger.info("i", "info")
        logger.warning("w", "warning")
        logger.error("e", "error")

        XCTAssertTrue(eventually { self.messages(of: "levels-\(self.shopId)").count == 2 })
        XCTAssertEqual(messages(of: "levels-\(shopId)").map(\.code), ["w", "e"])
    }

    func test_level_none_logs_nothing() {
        let logger = SdkLogger(shopId: "none-\(shopId)", level: .none)
        logger.error("e", "error")

        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertTrue(messages(of: "none-\(shopId)").isEmpty)
    }

    func test_the_handler_gets_the_shop_the_code_and_the_context_off_the_main_thread() {
        var onMain = true
        Rees46.setLogHandler { message in
            onMain = Thread.isMainThread
            self.lock.lock(); self.received.append(message); self.lock.unlock()
        }
        SdkLogger(shopId: "handler-\(shopId)", level: .debug).info("init_succeeded", "initialization finished", ["path": "init"])

        XCTAssertTrue(eventually { !self.messages(of: "handler-\(self.shopId)").isEmpty })
        let message = messages(of: "handler-\(shopId)")[0]
        XCTAssertEqual(message.level, .info)
        XCTAssertEqual(message.code, "init_succeeded")
        XCTAssertEqual(message.context["path"], "init")
        XCTAssertFalse(onMain)
    }

    func test_without_a_handler_nothing_is_delivered() {
        Rees46.setLogHandler(nil)
        SdkLogger(shopId: "nohandler-\(shopId)", level: .debug).error("e", "error")

        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertTrue(messages(of: "nohandler-\(shopId)").isEmpty)
    }

    func test_the_config_level_is_warning_by_default_and_enable_logs_means_debug() {
        XCTAssertEqual(Rees46Config(shopId: "a").logLevel, .warning)
        XCTAssertEqual(Rees46Config(shopId: "a", enableLogs: true).logLevel, .debug)
        XCTAssertEqual(Rees46Config(shopId: "a", logLevel: .error).logLevel, .error)
        XCTAssertEqual(Rees46Config(shopId: "a", enableLogs: true, logLevel: .none).logLevel, .none)
    }

    func test_requests_are_logged_by_method_and_path_only() {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId, logLevel: .debug) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)

        let done = expectation(description: "post")
        sdk.postRequest(path: "profile/set", params: ["email": "buyer@example.com", "phone": "+79990001122"]) { _ in
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(eventually { self.messages(of: self.shopId).contains { $0.code == "request" && $0.message == "POST profile/set" } })
        assertNoPersonalData(in: messages(of: shopId))
    }

    func test_an_error_answer_is_logged_without_its_body() {
        StubURLProtocol.handler = { request in
            request.path == "/profile/set"
                ? StubReply(400, json: #"{"status":"error","message":"Invalid email buyer@example.com"}"#)
                : StubURLProtocol.defaultHandler(request)
        }
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)

        let done = expectation(description: "post")
        sdk.postRequest(path: "profile/set", params: ["email": "buyer@example.com"]) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(eventually { self.messages(of: self.shopId).contains { $0.code == "request_failed" } })
        let failed = messages(of: shopId).first { $0.code == "request_failed" }
        XCTAssertEqual(failed?.level, .error)
        XCTAssertEqual(failed?.message, "400: POST profile/set")
        XCTAssertEqual(failed?.context["status"], "400")
        assertNoPersonalData(in: messages(of: shopId))
    }

    func test_the_init_answer_is_never_logged() {
        StubURLProtocol.handler = { request in
            request.path == "/init"
                ? StubReply(json: #"{"did":"secret-did-123","seance":"s","email":"buyer@example.com"}"#)
                : StubReply()
        }
        let ready = expectation(description: "init")
        _ = StubSDK.make(shopId: shopId, logLevel: .debug) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)

        XCTAssertTrue(eventually { self.messages(of: self.shopId).contains { $0.code == "init_succeeded" } })
        for message in messages(of: shopId) {
            XCTAssertFalse(message.message.contains("secret-did-123"), message.message)
            XCTAssertFalse(message.message.contains("buyer@example.com"), message.message)
        }
    }

    func test_a_request_is_logged_after_its_answer_with_method_path_and_status() {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId, logLevel: .debug) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)

        let done = expectation(description: "get")
        sdk.getProductInfo(id: "item-1") { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(eventually { self.messages(of: self.shopId).contains { $0.code == "request" && $0.context["path"] == "products/get" } })
        let request = messages(of: shopId).first { $0.code == "request" && $0.context["path"] == "products/get" }
        XCTAssertEqual(request?.level, .debug)
        XCTAssertEqual(request?.message, "GET products/get")
        XCTAssertEqual(request?.context["method"], "GET")
        XCTAssertEqual(request?.context["status"], "200")
    }

    func test_a_request_without_an_answer_is_logged_as_failed_without_a_status() {
        StubURLProtocol.handler = { $0.path == "/init" ? StubURLProtocol.defaultHandler($0) : StubReply.noAnswer }
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)

        let done = expectation(description: "post")
        sdk.postRequest(path: "push", params: ["event": "view"]) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(eventually { self.messages(of: self.shopId).contains { $0.code == "request_failed" } })
        let failed = messages(of: shopId).first { $0.code == "request_failed" }
        XCTAssertEqual(failed?.level, .warning)
        XCTAssertEqual(failed?.message, "no answer: POST push")
        XCTAssertNil(failed?.context["status"])
    }

    func test_custom_fields_that_are_not_json_are_an_invalid_argument() {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)

        let done = expectation(description: "event")
        sdk.trackEvent(event: "e", time: nil, category: nil, label: nil, value: nil, customFields: ["when": Date()]) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertTrue(eventually { self.messages(of: self.shopId).contains { $0.code == "invalid_argument" } })
        let message = messages(of: shopId).first { $0.code == "invalid_argument" }
        XCTAssertEqual(message?.level, .warning)
        XCTAssertEqual(message?.context["reason"], "invalid_json")
    }

    func test_deleting_the_user_credentials_logs_the_reset_and_releases_the_shop_level() {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId, logLevel: .info) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        XCTAssertEqual(SdkLogger.forShop(shopId).level, .info)

        sdk.deleteUserCredentials()

        XCTAssertTrue(eventually { self.messages(of: self.shopId).contains { $0.code == "device_id_reset" } })
        XCTAssertEqual(messages(of: shopId).first { $0.code == "device_id_reset" }?.level, .info)
        XCTAssertFalse(SdkLogger.registeredShopIds.contains(shopId))
        XCTAssertEqual(SdkLogger.forShop(shopId).level, .warning)
    }

    func test_a_released_owner_no_longer_sets_the_level_of_its_shop_or_of_the_process() {
        let shop = "owner-\(shopId)"
        let owner = NSObject()
        let other = NSObject()
        SdkLogger.register(SdkLogger(shopId: shop, level: .debug), owner: owner)
        SdkLogger.register(SdkLogger(shopId: shop, level: .error), owner: other)
        XCTAssertEqual(SdkLogger.forShop(shop).level, .debug, "the most verbose live instance of the shop")
        XCTAssertEqual(SdkLogger.process.level, .debug)

        SdkLogger.unregister(owner: owner)
        XCTAssertEqual(SdkLogger.forShop(shop).level, .error)
        SdkLogger.unregister(owner: other)
        XCTAssertFalse(SdkLogger.registeredShopIds.contains(shop))
    }

    func test_popups_v3_debug_lines_are_written_whatever_the_level() {
        let previous = PopupsV3Log.verbose
        defer { PopupsV3Log.verbose = previous }
        let shop = "popups-\(shopId)"
        SdkLogger.register(SdkLogger(shopId: shop, level: .none), owner: self)
        defer { SdkLogger.unregister(owner: self) }

        PopupsV3Log.verbose = true
        SdkLogger.area(.popupsV3, .debug, "forced line", shopId: shop, force: PopupsV3Log.verbose)
        PopupsV3Log.verbose = false
        SdkLogger.area(.popupsV3, .debug, "quiet line", shopId: shop, force: PopupsV3Log.verbose)

        XCTAssertTrue(eventually { !self.messages(of: shop).isEmpty })
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(messages(of: shop).map(\.message), ["forced line"])
        XCTAssertEqual(messages(of: shop).first?.code, "popups_v3")
    }

    func test_the_push_token_skipped_within_the_week_says_why() {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId, logLevel: .debug) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        let key = "mainPushTokenLastUploadDateKey.\(shopId)"
        UserDefaults.standard.set(Date(), forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: Data([1, 2, 3]))

        // The stub SDK does not send the token by itself: that skip is logged too, with its own reason.
        XCTAssertTrue(eventually {
            self.messages(of: self.shopId).contains { $0.code == "push_token_skipped" && $0.context["reason"] == "sent_recently" }
        })
        XCTAssertTrue(messages(of: shopId).contains { $0.code == "push_token_skipped" && $0.context["reason"] == "auto_send_off" })
    }

    func test_errors_are_logged_by_their_kind_never_by_their_text() {
        XCTAssertEqual(SdkLogger.errorKind(SdkError.custom(error: "Invalid email buyer@example.com")), "custom")
        XCTAssertEqual(SdkLogger.errorKind(SdkError.networkOfflineError), "networkOfflineError")
        let url = URL(string: "https://api.rees46.ru/products?did=secret-did&sid=secret-sid")
        let urlError = URLError(.timedOut, userInfo: [NSURLErrorFailingURLErrorKey: url as Any])
        XCTAssertEqual(SdkLogger.errorKind(urlError), "URLError -1001")
        XCTAssertFalse(SdkLogger.errorKind(urlError).contains("secret"))
        XCTAssertEqual(SdkLogger.errorKind(nil), "none")
    }

    private func assertNoPersonalData(in messages: [Rees46.SdkLogMessage], file: StaticString = #filePath, line: UInt = #line) {
        for message in messages {
            let text = message.message + " " + message.context.values.joined(separator: " ")
            XCTAssertFalse(text.contains("buyer@example.com"), text, file: file, line: line)
            XCTAssertFalse(text.contains("79990001122"), text, file: file, line: line)
            XCTAssertFalse(text.contains("Invalid email"), text, file: file, line: line)
        }
    }
}
