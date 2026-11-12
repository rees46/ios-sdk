//
//  InitRequestTests.swift
//  REES46Tests
//
//  `/init` goes to the server on every launch. The saved init answer (the documents file and its
//  keychain backup) stands in only when no answer came: offline, a dead connection.
//

import XCTest
@testable import REES46

final class InitRequestTests: XCTestCase {

    private var shopId = ""
    private let savedAnswer = Data(#"{"did":"kept-did","seance":"old-seance"}"#.utf8)

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        shopId = StubSDK.shopId()
        // The server knows the device id it is sent, and makes a new one only for a new device.
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            let did = request.query["did"] ?? "new-did"
            return StubReply(json: #"{"did":"\#(did)","seance":"server-seance"}"#)
        }
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubSDK.removeSavedInit(shopId: shopId)
        super.tearDown()
    }

    /// Builds the SDK and waits for its init; returns the SDK and the error init ended with.
    private func initialize(
        identity: UserIdentityRepository,
        keychain: KeychainInitStore
    ) -> (SimplePersonalizationSDK, SdkError?) {
        let ready = expectation(description: "init")
        var initError: SdkError?
        let sdk = StubSDK.make(shopId: shopId, identity: identity, keychain: keychain) { error in
            initError = error
            ready.fulfill()
        }
        wait(for: [ready], timeout: 5)
        return (sdk, initError)
    }

    func test_init_goes_to_the_server_while_a_saved_answer_is_in_the_keychain() {
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "kept-did"

        let (sdk, error) = initialize(identity: identity, keychain: InMemoryKeychainInitStore(savedAnswer))

        XCTAssertNil(error)
        XCTAssertEqual(StubURLProtocol.requests(to: "/init").count, 1, "the saved answer replaced /init")
        XCTAssertEqual(StubURLProtocol.requests(to: "/init").first?.query["did"], "kept-did")
        XCTAssertEqual(sdk.deviceId, "kept-did")
    }

    func test_init_goes_to_the_server_while_a_saved_answer_is_in_the_documents() throws {
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "kept-did"
        try savedAnswer.write(to: StubSDK.savedInitFile(shopId: shopId))

        let (_, error) = initialize(identity: identity, keychain: InMemoryKeychainInitStore(savedAnswer))

        XCTAssertNil(error)
        XCTAssertEqual(StubURLProtocol.requests(to: "/init").count, 1, "the saved answer replaced /init")
    }

    func test_after_a_reinstall_init_sends_the_device_id_kept_in_the_keychain() {
        // A reinstall wipes the app's storage; the keychain keeps the init answer.
        let identity = InMemoryUserIdentityRepository()

        let (sdk, error) = initialize(identity: identity, keychain: InMemoryKeychainInitStore(savedAnswer))

        XCTAssertNil(error)
        XCTAssertEqual(StubURLProtocol.requests(to: "/init").first?.query["did"], "kept-did")
        XCTAssertEqual(sdk.deviceId, "kept-did")
        XCTAssertEqual(identity.deviceId, "kept-did")
    }

    func test_without_an_answer_init_falls_back_to_the_saved_one() {
        StubURLProtocol.handler = { _ in StubReply.noAnswer }
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "kept-did"

        let (sdk, error) = initialize(identity: identity, keychain: InMemoryKeychainInitStore(savedAnswer))

        XCTAssertNil(error)
        XCTAssertEqual(sdk.deviceId, "kept-did")
        XCTAssertEqual(sdk.userInfo.deviceId, "kept-did")
    }

    func test_a_shop_the_server_refuses_is_not_covered_by_the_saved_answer() {
        StubURLProtocol.handler = { request in
            request.path == "/init" ? StubReply(402, json: #"{"status":"error","message":"Restricted Mode"}"#) : StubReply()
        }
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "kept-did"

        let (_, error) = initialize(identity: identity, keychain: InMemoryKeychainInitStore(savedAnswer))

        XCTAssertNotNil(error, "a refused shop must reach the app as an init error")
    }

    func test_a_new_device_without_a_saved_answer_gets_its_device_id_from_init() {
        let identity = InMemoryUserIdentityRepository()

        let (sdk, error) = initialize(identity: identity, keychain: InMemoryKeychainInitStore())

        XCTAssertNil(error)
        XCTAssertNil(StubURLProtocol.requests(to: "/init").first?.query["did"])
        XCTAssertEqual(sdk.deviceId, "new-did")
        XCTAssertEqual(identity.deviceId, "new-did")
    }
}
