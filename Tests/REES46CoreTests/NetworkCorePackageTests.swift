//
//  NetworkCorePackageTests.swift
//  REES46CoreTests
//
//  The parts of the new core's client that need no server: what an answer means, the common
//  fields, the mapping to the old errors and the process's core flag.
//

import XCTest
@testable import REES46

final class NetworkCorePackageTests: XCTestCase {

    override func tearDown() {
        CoreFlag.reset()
        super.tearDown()
    }

    func test_an_answer_is_classified_by_its_code_and_body() {
        XCTAssertNotNil(try? NetworkClient.classify(status: 200, body: Data(#"{"a":1}"#.utf8)).get())
        XCTAssertNotNil(try? NetworkClient.classify(status: 204, body: Data()).get(), "an empty 2xx is an empty success")
        XCTAssertNotNil(try? NetworkClient.classify(status: 299, body: Data("[]".utf8)).get())
        XCTAssertEqual(failure(NetworkClient.classify(status: 200, body: Data("nope".utf8))), .decoding)
        XCTAssertEqual(failure(NetworkClient.classify(status: 404, body: Data())), .http(code: 404, serverCode: nil))
        XCTAssertEqual(failure(NetworkClient.classify(status: 503, body: Data("{}".utf8))), .http(code: 503, serverCode: nil))
        XCTAssertEqual(NetworkClient.classify(URLError(.timedOut)), .timeout)
        XCTAssertEqual(NetworkClient.classify(URLError(.cancelled)), .cancelled)
        XCTAssertEqual(NetworkClient.classify(URLError(.notConnectedToInternet)), .network)
    }

    func test_retry_after_is_read_as_seconds() {
        XCTAssertEqual(NetworkClient.retryAfter("30"), 30)
        XCTAssertEqual(NetworkClient.retryAfter("-5"), 0)
        XCTAssertNil(NetworkClient.retryAfter(""))
    }

    func test_the_common_fields_fill_what_is_missing_and_leave_out_what_is_empty() {
        let fields = CommonFields(shopId: "shop", deviceId: "", sessionId: "sid", stream: "ios", segment: "B")
        let query = fields.apply(to: ["did": "", "seance": "own"], path: "recommend/1")
        XCTAssertNil(query["did"])
        XCTAssertEqual(query["sid"], "own")
        XCTAssertEqual(query["seance"], "own")
        XCTAssertEqual(query["shop_id"], "shop")
        XCTAssertEqual(query["segment"], "B")
        XCTAssertEqual(query["stream"], "ios")

        XCTAssertEqual(Set(fields.apply(to: ["tz": "3"], path: "init").keys), ["tz", "shop_id", "stream"])
        let secret = fields.apply(to: ["shop_secret": "s"] as [String: Any], path: "orders/by_user")
        XCTAssertNil(secret["sid"])
        XCTAssertNil(secret["segment"])
    }

    func test_the_new_errors_map_to_the_old_ones() {
        XCTAssertEqual(SdkError.legacy(.network).logKind, "networkOfflineError")
        XCTAssertEqual(SdkError.legacy(.timeout).logKind, "invalidResponse")
        XCTAssertEqual(SdkError.legacy(.decoding).logKind, "decodeError")
        XCTAssertEqual(SdkError.legacy(.notInitialized).logKind, "initializationFailed")
        XCTAssertEqual(SdkError.legacy(.http(code: 500, serverCode: nil)).logKind, "invalidResponse")
        XCTAssertEqual(SdkError.legacy(.http(code: 400, serverCode: nil), serverMessage: "m").description, "Custom Error: m")
        XCTAssertEqual(SdkError.legacy(.shopBlocked).description, "Custom Error: shop blocked")
    }

    func test_the_core_flag_is_one_per_process() {
        CoreFlag.reset()
        XCTAssertNil(CoreFlag.current)
        XCTAssertFalse(CoreFlag.resolve(requested: false, shopId: nil))
        XCTAssertFalse(CoreFlag.resolve(requested: true, shopId: nil))
        XCTAssertEqual(CoreFlag.current, false)
    }

    private func failure(_ result: Result<Any, Rees46.SdkError>) -> Rees46.SdkError? {
        if case let .failure(error) = result { return error }
        return nil
    }
}
