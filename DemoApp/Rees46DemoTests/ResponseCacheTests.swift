import XCTest
@testable import REES46

/// The data widgets' in-memory response cache: keyed by shop, request kind and parameters,
/// 10-minute TTL, at most 32 entries with the oldest evicted first, identical in-flight
/// requests coalesced, errors never stored.
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
        _ cache: ResponseCache, _ key: ResponseCache.Key, answer: Result<String, SdkError> = .success("value")
    ) -> Result<String, SdkError>? {
        var received: Result<String, SdkError>?
        cache.fetch(key, load: { (done: @escaping (Result<String, SdkError>) -> Void) in
            self.loads += 1
            done(answer)
        }, completion: { received = $0 })
        return received
    }

    /// Fetches through a load that stays in flight until `pending` is completed.
    private func fetchPending(_ cache: ResponseCache, _ key: ResponseCache.Key, into results: @escaping (Result<String, SdkError>) -> Void) {
        cache.fetch(key, load: { (done: @escaping (Result<String, SdkError>) -> Void) in
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

    func testRemoveAll_forgetsAnswers() {
        let cache = makeCache()
        fetch(cache, key())
        cache.removeAll()
        fetch(cache, key())
        XCTAssertEqual(loads, 2)
    }
}
