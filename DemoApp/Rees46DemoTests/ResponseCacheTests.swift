import XCTest
@testable import REES46

/// The data widgets' in-memory response cache: keyed by shop, request kind and parameters,
/// 10-minute TTL, at most 32 entries with the oldest evicted first, identical in-flight
/// requests coalesced, errors never stored. A request in flight cannot lock its key: after
/// 30 seconds, after every caller unsubscribed, after `clear()` or with `force` a new load starts.
final class ResponseCacheTests: XCTestCase {

    private var clock = Date(timeIntervalSince1970: 0)
    private var loads = 0
    /// Completions of loads still in flight, to finish them by hand.
    private var pending: [(Result<String, SdkError>) -> Void] = []

    override func setUp() {
        super.setUp()
        clock = Date(timeIntervalSince1970: 0)
        loads = 0
        pending = []
    }

    private func makeCache(capacity: Int = 32) -> ResponseCache {
        ResponseCache(ttl: 600, capacity: capacity) { [unowned self] in self.clock }
    }

    private func key(_ code: String = "block", shop: String = "shop", kind: String = "recommend") -> ResponseCache.Key {
        ResponseCache.Key(shopId: shop, kind: kind, params: ["code": code])
    }

    /// Fetches through a load that answers right away with `answer`.
    @discardableResult
    private func fetch(
        _ cache: ResponseCache, _ key: ResponseCache.Key, force: Bool = false,
        answer: Result<String, SdkError> = .success("value")
    ) -> Result<String, SdkError>? {
        var received: Result<String, SdkError>?
        cache.fetch(key, force: force, load: { (done: @escaping (Result<String, SdkError>) -> Void) in
            self.loads += 1
            done(answer)
        }, completion: { received = $0 })
        return received
    }

    /// Fetches through a load that stays in flight until `pending` is completed.
    @discardableResult
    private func fetchPending(
        _ cache: ResponseCache, _ key: ResponseCache.Key, force: Bool = false,
        into results: @escaping (Result<String, SdkError>) -> Void
    ) -> Cancellable {
        cache.fetch(key, force: force, load: { (done: @escaping (Result<String, SdkError>) -> Void) in
            self.loads += 1
            self.pending.append(done)
        }, completion: results)
    }

    func testHit_withinTtl_answersFromCache() {
        let cache = makeCache()
        fetch(cache, key(), answer: .success("first"))
        clock += 599

        let result = fetch(cache, key(), answer: .success("second"))

        XCTAssertEqual(try result?.get(), "first")
        XCTAssertEqual(loads, 1)
    }

    func testExpired_afterTtl_loadsAgain() {
        let cache = makeCache()
        fetch(cache, key(), answer: .success("first"))
        clock += 600

        let result = fetch(cache, key(), answer: .success("second"))

        XCTAssertEqual(try result?.get(), "second")
        XCTAssertEqual(loads, 2)
    }

    func testKey_separatesShopsKindsAndParameters() {
        let cache = makeCache()
        fetch(cache, key())
        fetch(cache, key("other"))
        fetch(cache, key(shop: "other-shop"))
        fetch(cache, key(kind: "collection"))
        XCTAssertEqual(loads, 4)

        fetch(cache, key())
        XCTAssertEqual(loads, 4)
    }

    func testCapacity_evictsTheOldestEntry() {
        let cache = makeCache(capacity: 2)
        fetch(cache, key("a"))
        clock += 1
        fetch(cache, key("b"))
        clock += 1
        fetch(cache, key("c"))
        XCTAssertEqual(loads, 3)

        fetch(cache, key("b"))
        fetch(cache, key("c"))
        XCTAssertEqual(loads, 3)

        fetch(cache, key("a"))
        XCTAssertEqual(loads, 4)
    }

    func testDefaultCapacity_is32() {
        let cache = ResponseCache { [unowned self] in self.clock }
        for index in 0..<33 { fetch(cache, key("\(index)")) }
        XCTAssertEqual(loads, 33)

        fetch(cache, key("32"))
        fetch(cache, key("1"))
        XCTAssertEqual(loads, 33)
        fetch(cache, key("0"))
        XCTAssertEqual(loads, 34)
    }

    func testInFlight_sameKey_loadsOnce_andAnswersEveryCaller() {
        let cache = makeCache()
        var results: [String] = []
        fetchPending(cache, key()) { results.append((try? $0.get()) ?? "error") }
        fetchPending(cache, key()) { results.append((try? $0.get()) ?? "error") }
        XCTAssertEqual(loads, 1)
        XCTAssertTrue(results.isEmpty)

        pending[0](.success("value"))

        XCTAssertEqual(results, ["value", "value"])
        fetch(cache, key())
        XCTAssertEqual(loads, 1)
    }

    func testErrors_reachEveryCaller_andAreNotCached() {
        let cache = makeCache()
        var failures = 0
        fetchPending(cache, key()) { if case .failure = $0 { failures += 1 } }
        fetchPending(cache, key()) { if case .failure = $0 { failures += 1 } }

        pending[0](.failure(.networkOfflineError))

        XCTAssertEqual(failures, 2)
        let retry = fetch(cache, key(), answer: .success("value"))
        XCTAssertEqual(try retry?.get(), "value")
        XCTAssertEqual(loads, 2)
    }

    func testClear_forgetsAnswers() {
        let cache = makeCache()
        fetch(cache, key())
        cache.clear()
        fetch(cache, key())
        XCTAssertEqual(loads, 2)
    }

    // MARK: - A request in flight cannot lock its key

    func testInFlight_unanswered30Seconds_nextCallLoadsAgain() {
        let cache = makeCache()
        var results: [String] = []
        fetchPending(cache, key()) { results.append("old:" + ((try? $0.get()) ?? "error")) }
        clock += 29
        fetchPending(cache, key()) { results.append("joined:" + ((try? $0.get()) ?? "error")) }
        XCTAssertEqual(loads, 1)

        clock += 1
        fetchPending(cache, key()) { results.append("new:" + ((try? $0.get()) ?? "error")) }
        XCTAssertEqual(loads, 2)

        pending[1](.success("fresh"))
        pending[0](.success("stale"))

        XCTAssertEqual(results, ["new:fresh", "old:stale", "joined:stale"])
        // The old generation's late answer did not overwrite the newer one.
        XCTAssertEqual(try fetch(cache, key())?.get(), "fresh")
        XCTAssertEqual(loads, 2)
    }

    func testEveryCallerUnsubscribed_keyLoadsAgain_andTheCancelledAreNotCalled() {
        let cache = makeCache()
        var results: [String] = []
        let first = fetchPending(cache, key()) { _ in results.append("first") }
        let second = fetchPending(cache, key()) { _ in results.append("second") }
        first.cancel()
        second.cancel()

        fetchPending(cache, key()) { _ in results.append("third") }
        XCTAssertEqual(loads, 2)

        pending[0](.success("value"))
        pending[1](.success("value"))
        XCTAssertEqual(results, ["third"])
    }

    func testCancelledCaller_isSkipped_theOthersStillGetTheAnswer() {
        let cache = makeCache()
        var results: [String] = []
        let first = fetchPending(cache, key()) { _ in results.append("first") }
        fetchPending(cache, key()) { _ in results.append("second") }
        first.cancel()

        pending[0](.success("value"))

        XCTAssertEqual(loads, 1)
        XCTAssertEqual(results, ["second"])
    }

    func testClear_duringFlight_answerReachesCallerButIsNotStored() {
        let cache = makeCache()
        var received: String?
        fetchPending(cache, key()) { received = try? $0.get() }
        cache.clear()

        pending[0](.success("value"))

        XCTAssertEqual(received, "value")
        fetch(cache, key())
        XCTAssertEqual(loads, 2)
    }

    func testClear_duringFlight_nextCallDoesNotJoinIt() {
        let cache = makeCache()
        fetchPending(cache, key()) { _ in }
        cache.clear()
        fetchPending(cache, key()) { _ in }
        XCTAssertEqual(loads, 2)
    }

    func testForce_bypassesTheStoredAnswer_andStoresTheNewOne() {
        let cache = makeCache()
        fetch(cache, key(), answer: .success("first"))

        let forced = fetch(cache, key(), force: true, answer: .success("second"))

        XCTAssertEqual(try forced?.get(), "second")
        XCTAssertEqual(loads, 2)
        XCTAssertEqual(try fetch(cache, key())?.get(), "second")
        XCTAssertEqual(loads, 2)
    }

    func testForce_doesNotJoinTheRequestInFlight() {
        let cache = makeCache()
        fetchPending(cache, key()) { _ in }
        fetchPending(cache, key(), force: true) { _ in }
        XCTAssertEqual(loads, 2)
    }
}
