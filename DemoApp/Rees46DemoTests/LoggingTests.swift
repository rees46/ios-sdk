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
    private var received: [SdkLogMessage] = []

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

    private var messages: [SdkLogMessage] {
        lock.lock(); defer { lock.unlock() }
        return received
    }

    private func messages(of shop: String) -> [SdkLogMessage] {
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

    private func assertNoPersonalData(in messages: [SdkLogMessage], file: StaticString = #filePath, line: UInt = #line) {
        for message in messages {
            let text = message.message + " " + message.context.values.joined(separator: " ")
            XCTAssertFalse(text.contains("buyer@example.com"), text, file: file, line: line)
            XCTAssertFalse(text.contains("79990001122"), text, file: file, line: line)
            XCTAssertFalse(text.contains("Invalid email"), text, file: file, line: line)
        }
    }
}
