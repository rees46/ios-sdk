import XCTest
@testable import REES46

/// The data widgets' load state: `idle → loading → content | empty | error`, retry after an error,
/// stale answers dropped, state changed only on the main queue.
final class LoadStateMachineTests: XCTestCase {

    private var fetches = 0
    /// Completions of fetches still in flight, to finish them by hand.
    private var pending: [(Result<[String], SdkError>) -> Void] = []
    private var machine: LoadStateMachine<[String]>!

    override func setUp() {
        super.setUp()
        fetches = 0
        pending = []
        machine = LoadStateMachine(fetch: { [unowned self] done in
            self.fetches += 1
            self.pending.append(done)
        }, isEmpty: { $0.isEmpty })
    }

    override func tearDown() {
        machine = nil
        super.tearDown()
    }

    /// The state as a short string, since `SdkError` is not `Equatable`.
    private var state: String {
        switch machine.state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .content(let items): return "content(\(items.joined(separator: ",")))"
        case .empty: return "empty"
        case .error: return "error"
        }
    }

    func testStartsIdle() {
        XCTAssertEqual(state, "idle")
        XCTAssertEqual(fetches, 0)
    }

    func testLoad_goesThroughLoadingToContent() {
        var seen: [String] = []
        machine.onChange = { [unowned self] _ in seen.append(self.state) }

        machine.load()
        pending[0](.success(["a", "b"]))

        XCTAssertEqual(seen, ["loading", "content(a,b)"])
    }

    func testEmptyAnswer_isEmpty() {
        machine.load()
        pending[0](.success([]))

        XCTAssertEqual(state, "empty")
    }

    func testFailure_isError_andRetryLoadsAgain() {
        machine.load()
        pending[0](.failure(.networkOfflineError))
        XCTAssertEqual(state, "error")

        machine.retry()
        XCTAssertEqual(state, "loading")
        XCTAssertEqual(fetches, 2)

        pending[1](.success(["a"]))
        XCTAssertEqual(state, "content(a)")
    }

    func testRetry_outsideError_doesNothing() {
        machine.retry()
        XCTAssertEqual(state, "idle")

        machine.load()
        machine.retry()
        XCTAssertEqual(fetches, 1)

        pending[0](.success(["a"]))
        machine.retry()
        XCTAssertEqual(fetches, 1)
        XCTAssertEqual(state, "content(a)")
    }

    func testNewLoad_dropsTheStaleAnswer() {
        machine.load()
        machine.load()

        pending[0](.success(["stale"]))
        XCTAssertEqual(state, "loading")

        pending[1](.success(["fresh"]))
        XCTAssertEqual(state, "content(fresh)")
    }

    func testReset_dropsTheAnswerInFlight() {
        machine.load()
        machine.reset()
        XCTAssertEqual(state, "idle")

        pending[0](.success(["late"]))
        XCTAssertEqual(state, "idle")
    }

    func testBackgroundAnswer_changesStateOnMainQueue() {
        let changed = expectation(description: "state changed")
        machine.onChange = { [unowned self] _ in
            XCTAssertTrue(Thread.isMainThread)
            if case .content = self.machine.state { changed.fulfill() }
        }

        machine.load()
        let done = pending[0]
        DispatchQueue.global().async { done(.success(["a"])) }

        wait(for: [changed], timeout: 5)
    }
}
