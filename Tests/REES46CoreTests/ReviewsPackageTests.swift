//
//  ReviewsPackageTests.swift
//  REES46CoreTests
//
//  `reviews` without a server: the request each call of the proposed fixture builds — its host too —
//  or the argument it refuses, what the request path makes of each answer, and the host of API v3 in the
//  client's URL.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class ReviewsPackageTests: XCTestCase {

    private let logger = SdkLogger(shopId: "package-\(UUID().uuidString)", level: .none)

    // MARK: - The fixture

    func test_each_call_of_the_fixture_builds_its_request_on_its_host_or_refuses_its_argument() throws {
        let cases = try ContractFixtures.fixture("reviews", from: .proposed).filter { $0.response == nil }
        XCTAssertGreaterThanOrEqual(cases.count, 20)
        var methods: Set<String> = []
        for item in cases {
            let call = try XCTUnwrap(item.call, item.name)
            methods.insert(call.method)
            if let error = item.expectedError {
                XCTAssertThrowsError(try ReviewsFixtureCalls.request(for: call), item.name) { thrown in
                    let refusal = thrown as? Rees46.SdkError
                    XCTAssertTrue(refusal.map(error.matches) == true, "\(item.name): \(thrown)")
                }
                continue
            }
            let expected = try XCTUnwrap(item.request, item.name)
            let request = try ReviewsFixtureCalls.request(for: call)
            XCTAssertEqual(request.method.rawValue, expected.method, item.name)
            XCTAssertEqual(request.path, expected.path, item.name)
            XCTAssertEqual(request.host, ReviewsFixtureCalls.host(of: expected.path), item.name)
            // Only the fields the case lists: the common ones the core adds later.
            XCTAssertEqual(request.query, expected.query, item.name)
            XCTAssertEqual(ReviewsFixtureCalls.canonical(request.body), ReviewsFixtureCalls.canonical(expected.body), item.name)
        }
        XCTAssertEqual(methods.count, 9, "every method of the namespace: \(methods.sorted())")
    }

    func test_each_answer_of_the_fixture_ends_as_the_fixture_says() throws {
        // A case without an answer runs over the stub server (`ReviewsRequestTests`).
        let cases = try ContractFixtures.fixture("reviews", from: .proposed).filter { $0.response?.status != nil }
        XCTAssertGreaterThanOrEqual(cases.count, 20)
        for item in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let response = try XCTUnwrap(item.response, item.name)
            let status = try XCTUnwrap(response.status, item.name)
            let request = try ReviewsFixtureCalls.request(for: call)
            let answer = NetworkClient.Response(
                status: status, body: response.body, retryAfter: nil,
                result: NetworkClient.classify(status: status, body: response.body, path: request.path)
            )
            switch request.value(answer, logger) {
            case .success(let value):
                XCTAssertNil(item.expectedError, "\(item.name): \(value)")
                XCTAssertTrue(
                    ReviewsFixtureCalls.matches(value, item.expect["result"]),
                    "\(item.name): \(ReviewsFixtureCalls.canonical(ReviewsFixtureCalls.json(value)))"
                )
            case .failure(let error):
                XCTAssertTrue(item.expectedError?.matches(error) == true, "\(item.name): \(error), expected \(String(describing: item.expectedError))")
            }
        }
    }

    func test_the_reviews_fixture_is_proposed_until_the_contract_has_one() throws {
        XCTAssertEqual(try ContractFixtures.load("reviews", from: .proposed)["contract"] as? String, ContractFixtures.version)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: ContractFixtures.url("reviews").path),
            "the contract has reviews.json now: copy it into contract-\(ContractFixtures.version) and remove the proposed one"
        )
    }

    // MARK: - Answers beside the fixture

    /// The value of `body`, a `200`, for `request`.
    private func value(_ request: ReviewsFixtureCalls.Request, _ body: String) -> Result<Any, Rees46.SdkError> {
        let data = Data(body.utf8)
        let answer = NetworkClient.Response(status: 200, body: data, retryAfter: nil, result: NetworkClient.classify(status: 200, body: data))
        return request.value(answer, logger)
    }

    private func call(_ method: String, _ args: [String: Any] = [:]) throws -> ReviewsFixtureCalls.Request {
        try ReviewsFixtureCalls.request(for: ContractCase.Call(namespace: "reviews", method: method, args: args))
    }

    func test_an_answer_without_a_body_is_an_empty_list_or_no_reviews_but_no_score() throws {
        for method in ["getNpsCategories", "getNpsChannels", "getCsatCampaigns", "getCesCampaigns"] {
            XCTAssertEqual((try? value(try call(method), "").get() as? [Any])?.count, 0, method)
        }
        XCTAssertEqual((try? value(try call("getClientReviews", ["orderId": "A-1"]), "").get() as? [ClientReview])?.count, 0)
        let none = try? value(try call("getProductReviews", ["itemId": "37"]), "").get() as? ProductReviewsResponse
        XCTAssertEqual(none, ProductReviewsResponse(summary: ProductRatingSummary(count: 0), reviews: []))
        for method in ["createNps", "createCsat", "createCes"] {
            let score = try call(method, ["rate": 5, "channel": "c", "category": "x", "campaign": "x"])
            XCTAssertEqual(value(score, "").error, .decoding, "\(method): a score without its id")
            XCTAssertEqual(value(score, "{}").error, .decoding)
            XCTAssertEqual(value(score, #"{"payload": {"review": {"id": 2.5}}}"#).error, .decoding)
        }
    }

    func test_a_dictionary_needs_its_list_in_the_payload() throws {
        let categories = try call("getNpsCategories")
        XCTAssertEqual(value(categories, "{}").error, .decoding)
        XCTAssertEqual(value(categories, #"{"payload": {"categories": null}}"#).error, .decoding)
        XCTAssertEqual(value(categories, #"{"payload": {"categories": {"code": "a"}}}"#).error, .decoding)
        XCTAssertEqual(value(categories, #"{"payload": []}"#).error, .decoding)
        XCTAssertEqual(value(categories, "[]").error, .decoding)
        let read = try? value(categories, #"{"payload": {"categories": [{"code": 7, "name": "Seven"}, {"code": "x", "name": " "}, null, 3]}}"#).get() as? [NpsCategory]
        XCTAssertEqual(read, [NpsCategory(code: "7", name: "Seven")], "a code as a number is its digits; a blank name is none")
    }

    func test_the_rating_of_a_product_reads_its_scores_leniently() throws {
        let reviews = try call("getProductReviews", ["itemId": "37"])
        let body = #"{"payload": {"summary": {"count": "2", "average_rating": "4.5", "ratings": {"4": 1, "5": "1", "x": 3, "3": null}}, "reviews": []}}"#
        let read = try? value(reviews, body).get() as? ProductReviewsResponse
        XCTAssertEqual(read?.summary, ProductRatingSummary(count: 2, averageRating: 4.5, ratings: [4: 1, 5: 1]))
        XCTAssertEqual(value(reviews, #"{"payload": {"summary": {"average_rating": 4}, "reviews": []}}"#).error, .decoding, "no count")
        XCTAssertEqual(value(reviews, #"{"payload": {"summary": {"count": 0}}}"#).error, .decoding, "no list")
        let noRatings = try? value(reviews, #"{"payload": {"summary": {"count": 0, "ratings": [1, 2]}, "reviews": []}}"#).get() as? ProductReviewsResponse
        XCTAssertEqual(noRatings?.summary.ratings, [:])
    }

    func test_optional_arguments_go_only_when_they_are_given() throws {
        let blank = try call("createNps", ["rate": 9, "channel": "c", "category": "x", "orderId": " ", "comment": "\n", "label": ""])
        XCTAssertEqual(blank.body.keys.sorted(), ["category", "channel", "rate"])
        let given = try call("createCsat", ["rate": 3, "channel": "c", "campaign": "x", "comment": " ok "])
        XCTAssertEqual(given.body["comment"] as? String, " ok ", "a comment goes as it is")
        XCTAssertEqual(given.body["rate"] as? Int, 3, "the score is a number of JSON")
        XCTAssertEqual(try call("getProductReviews", ["itemId": "37", "limit": 100, "offset": 0]).query, ["product": "37", "limit": "100", "offset": "0"])
        XCTAssertThrowsError(try call("getClientReviews", ["orderId": " \n"]))
        XCTAssertThrowsError(try call("createNps", ["rate": 9, "channel": "\t", "category": "x"]))
    }

    func test_the_answer_of_a_score_with_an_error_in_a_2xx_is_decoding() throws {
        let score = try call("createNps", ["rate": 9, "channel": "c", "category": "x"])
        XCTAssertEqual(value(score, #"{"status": "error", "payload": {"review": {"id": 1}}}"#).error, .decoding)
        XCTAssertEqual((try? value(score, #"{"status": "success", "payload": {"review": {"id": " 41 "}}}"#).get()) as? PollReview, PollReview(id: 41))
    }

    // MARK: - The host of API v3 in the client

    func test_a_request_with_a_host_of_its_own_goes_there_and_the_others_to_the_api() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HostCapture.self]
        let client = NetworkClient(
            baseURL: "https://api.example.test/", configuration: configuration, connectivity: AlwaysOnline(), logger: logger
        ) {
            CommonFields(shopId: "shop", deviceId: "did", sessionId: "sid", stream: "ios", segment: "A")
        }
        HostCapture.reset()
        _ = await client.send(NetworkClient.Request(method: .get, path: "api/v3/polls/nps/channels", host: "app.cluster.test"))
        _ = await client.send(NetworkClient.Request(method: .post, path: "api/v3/polls/nps/reviews", body: ["rate": 9], host: "app.cluster.test"))
        _ = await client.send(NetworkClient.Request(method: .get, path: "reviews/product", query: ["product": "37"]))
        let urls = HostCapture.urls
        XCTAssertEqual(urls.map(\.host), ["app.cluster.test", "app.cluster.test", "api.example.test"])
        XCTAssertEqual(urls.map(\.scheme), ["https", "https", "https"])
        XCTAssertEqual(urls.map(\.path), ["/api/v3/polls/nps/channels", "/api/v3/polls/nps/reviews", "/reviews/product"])
        XCTAssertTrue(urls.first?.query?.contains("did=did") == true, "the common fields go to API v3 too")
        await client.release()
    }
}

private extension Result {
    var error: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

/// Online, always.
private final class AlwaysOnline: ConnectivityMonitor {
    var isOnline: Bool { true }

    func observe(_ handler: @escaping (Bool) -> Void) -> Cancellable {
        handler(true)
        return Cancellable {}
    }
}

/// Answers every request with `200 {}` and keeps its URL.
private final class HostCapture: URLProtocol {

    private static let lock = NSLock()
    private static var seen: [URL] = []

    static var urls: [URL] {
        lock.lock(); defer { lock.unlock() }
        return seen
    }

    static func reset() {
        lock.lock(); seen = []; lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url {
            Self.lock.lock(); Self.seen.append(url); Self.lock.unlock()
        }
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
