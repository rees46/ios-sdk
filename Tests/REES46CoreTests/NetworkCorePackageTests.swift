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
        XCTAssertEqual(failure(NetworkClient.classify(status: 200, body: Data(), path: "init")), .decoding, "an empty /init has no device id")
        XCTAssertNotNil(try? NetworkClient.classify(status: 200, body: Data(), path: "push").get())
        XCTAssertEqual(NetworkClient.classify(URLError(.timedOut), reachedServer: true), .timeout)
        XCTAssertEqual(NetworkClient.classify(URLError(.timedOut), reachedServer: false), .network, "a connect that timed out")
        // Without the session's metrics a timed-out request is a timeout, anything else no network.
        XCTAssertEqual(NetworkClient.classify(URLError(.timedOut), reachedServer: nil), .timeout)
        XCTAssertEqual(NetworkClient.classify(URLError(.cannotConnectToHost), reachedServer: nil), .network)
        XCTAssertEqual(NetworkClient.classify(URLError(.cancelled), reachedServer: nil), .cancelled)
        XCTAssertEqual(NetworkClient.classify(URLError(.networkConnectionLost), reachedServer: true), .timeout, "an answer cut midway")
        XCTAssertEqual(NetworkClient.classify(URLError(.cancelled), reachedServer: true), .cancelled)
        XCTAssertEqual(NetworkClient.classify(URLError(.notConnectedToInternet), reachedServer: false), .network)
    }

    /// The API sets a `did` cookie and answers an `/init` without a did by it: no session of the SDK
    /// sends or keeps cookies, the copy of an app's configuration included (`CookieTests` over the stub).
    func test_the_sessions_of_the_sdk_neither_send_nor_keep_cookies() {
        let app = URLSessionConfiguration.default
        let configurations: [(String, URLSessionConfiguration)] = [
            ("NetworkClient", NetworkClient.configuration()),
            ("LegacyCore waiting", LegacyCore.sessionConfiguration(waitsForConnectivity: true)),
            ("LegacyCore not waiting", LegacyCore.sessionConfiguration(waitsForConnectivity: false)),
            ("SdkURLSession", SdkURLSession.shared.configuration),
            ("the app's, copied", app.withoutCookies()),
        ]
        for (name, configuration) in configurations {
            XCTAssertFalse(configuration.httpShouldSetCookies, name)
            XCTAssertEqual(configuration.httpCookieAcceptPolicy, .never, name)
            XCTAssertNil(configuration.httpCookieStorage, name)
        }
        XCTAssertTrue(app.httpShouldSetCookies, "the app's configuration is left as it was")
        XCTAssertNotNil(app.httpCookieStorage)
    }

    func test_retry_after_is_read_as_seconds() {
        XCTAssertEqual(NetworkClient.retryAfter("30"), 30)
        XCTAssertNil(NetworkClient.retryAfter("-5"))
        XCTAssertNil(NetworkClient.retryAfter(""))
        for value in ["inf", "-inf", "nan", "1e400", "infinity"] {
            XCTAssertNil(NetworkClient.retryAfter(value), value)
        }
        XCTAssertEqual(NetworkClient.retryAfter("86400000"), 86_400_000, "a number, held to five minutes by the policy")
        XCTAssertEqual(RetryPolicy.pause(retryAfter: 86_400_000), 300)
        XCTAssertEqual(RetryPolicy.pause(retryAfter: 0), 1)
        XCTAssertEqual(RetryPolicy.pause(retryAfter: 42), 42)
        XCTAssertEqual(RetryPolicy.pause(retryAfter: nil, afterFailures: 3, random: 0.5), 4)
        // Only a 429 or a 503 has one that counts.
        XCTAssertEqual(NetworkClient.retryAfter("7", status: 429), 7)
        XCTAssertEqual(NetworkClient.retryAfter("7", status: 503), 7)
        for status in [500, 502, 408, 200, 404] {
            XCTAssertNil(NetworkClient.retryAfter("7", status: status), "\(status)")
        }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let past = "Sun, 06 Nov 1994 08:49:37 GMT"
        XCTAssertEqual(NetworkClient.retryAfter(past, now: now), 0)
        // Whatever comes in the header, nothing traps: non-ASCII digits, a date in another script.
        for value in ["５", "١٢٠", "🙂", "Вс, 06 ноя 1994 08:49:37 GMT", "1٢", "\u{0}", String(repeating: "9", count: 400)] {
            let seconds = NetworkClient.retryAfter(value, status: 503)
            XCTAssertTrue(seconds == nil || seconds?.isFinite == true, value)
            _ = RetryPolicy.pause(retryAfter: seconds, afterFailures: 1, random: 0.5)
        }
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
        XCTAssertFalse(CoreFlag.resolve(requested: false))
        XCTAssertFalse(CoreFlag.resolve(requested: true))
        XCTAssertEqual(CoreFlag.current, false)
    }

    private func failure(_ result: Result<Any, Rees46.SdkError>) -> Rees46.SdkError? {
        if case let .failure(error) = result { return error }
        return nil
    }
}
