//
//  CoreSafetyTests.swift
//  REES46Tests
//
//  App data the SDK cannot write as JSON fails the call instead of crashing the app, a keychain item
//  that is not data is an error, and the network monitor never leaves a reader waiting.
//

import XCTest
@testable import REES46

final class CoreSafetyTests: XCTestCase {

    private var shopId = ""

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        shopId = StubSDK.shopId()
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubSDK.removeSavedInit(shopId: shopId)
        super.tearDown()
    }

    private func initializedSDK() -> SimplePersonalizationSDK {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        return sdk
    }

    func test_safe_json_writes_json_and_refuses_what_is_not() {
        XCTAssertNotNil(SafeJSON.data(["a": 1, "b": ["c": "d"]]))
        XCTAssertNil(SafeJSON.data(["date": Date()]))
        XCTAssertNil(SafeJSON.data(["nan": Double.nan]))
        XCTAssertNil(SafeJSON.data(["object": NSObject()]))
        XCTAssertNil(SafeJSON.data("not a container"))
    }

    func test_a_post_with_parameters_that_are_not_json_fails_and_sends_nothing() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        var outcome: Result<[String: Any], SdkError>?
        sdk.postRequest(path: "push/custom", params: ["event": "e", "when": Date()]) { result in
            outcome = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        guard case let .failure(.custom(message))? = outcome else {
            return XCTFail("expected a failure, got \(String(describing: outcome))")
        }
        XCTAssertTrue(message.contains("not valid JSON"), message)
        XCTAssertTrue(StubURLProtocol.requests(to: "/push/custom", shop: shopId).isEmpty)
    }

    func test_custom_fields_that_are_not_json_fail_the_event() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        var outcome: Result<Void, SdkError>?
        sdk.trackEvent(event: "e", time: nil, category: nil, label: nil, value: nil, customFields: ["when": Date()]) { result in
            outcome = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        guard case .failure? = outcome else { return XCTFail("expected a failure") }
        XCTAssertTrue(StubURLProtocol.requests(to: "/push/custom", shop: shopId).isEmpty)
    }

    func test_search_filters_that_are_not_json_fail_the_call_and_send_nothing() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        var outcome: Result<SearchResponse, SdkError>?
        sdk.search(query: "dress", filters: ["when": Date()]) { result in
            outcome = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        assertNotJSONFailure(outcome.map { $0.map { _ in () } })
        XCTAssertTrue(StubURLProtocol.requests(to: "/search", shop: shopId).isEmpty)
    }

    func test_products_list_filters_that_are_not_json_fail_the_call_and_send_nothing() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        var outcome: Result<ProductsListResponse, SdkError>?
        sdk.getProductsList(brands: nil, merchants: nil, categories: nil, locations: nil, limit: nil, page: nil, filters: ["nan": Double.nan]) { result in
            outcome = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        assertNotJSONFailure(outcome.map { $0.map { _ in () } })
        XCTAssertTrue(StubURLProtocol.requests(to: "/products", shop: shopId).isEmpty)
    }

    func test_category_filters_that_are_not_json_fail_the_call_and_send_nothing() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        done.expectedFulfillmentCount = 2
        let lock = NSLock()
        var outcomes: [Result<CategoryResponse, SdkError>] = []
        sdk.getCategory(category: "7", limit: nil, page: nil, brands: nil, locations: nil, filters: ["object": NSObject()]) { result in
            lock.lock(); outcomes.append(result); lock.unlock()
            done.fulfill()
        }
        sdk.getCategory(category: "7", limit: nil, page: nil, brands: nil, locations: nil, filters: ["when": Date()], priceMin: 1, priceMax: nil, sortBy: nil, sortDir: nil) { result in
            lock.lock(); outcomes.append(result); lock.unlock()
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(outcomes.count, 2)
        outcomes.forEach { assertNotJSONFailure($0.map { _ in () }) }
        XCTAssertTrue(StubURLProtocol.requests(to: "/category/7", shop: shopId).isEmpty)
    }

    func test_filters_that_are_json_still_go_with_the_request() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        sdk.getProductsList(brands: nil, merchants: nil, categories: nil, locations: nil, limit: nil, page: nil, filters: ["color": ["red"]]) { _ in
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(StubURLProtocol.requests(to: "/products", shop: shopId).first?.query["filters"], #"{"color":["red"]}"#)
    }

    func test_profile_properties_that_are_not_json_fail_the_call_and_send_nothing() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        var outcome: Result<Void, SdkError>?
        sdk.setProfileData(userEmail: nil, customProperties: ["object": NSObject(), "nan": Double.nan]) { result in
            outcome = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        assertNotJSONFailure(outcome)
        XCTAssertTrue(StubURLProtocol.requests(to: "/profile/set", shop: shopId).isEmpty)
    }

    func test_a_keychain_item_that_is_not_data_is_an_error_not_a_crash() {
        let original = InitService.copyMatching
        defer { InitService.copyMatching = original }
        InitService.copyMatching = { _, result in
            result?.pointee = "not data" as CFString
            return errSecSuccess
        }

        XCTAssertThrowsError(try InitService.getKeychainDidToken(identifier: "account", instanceKeychainService: "service"))
        let store = KeychainInitStoreImpl(shopId: shopId, service: "core-safety-tests")
        XCTAssertNil(store.readInitData())
    }

    func test_a_cellular_path_without_a_radio_is_still_a_cellular_connection() {
        XCTAssertEqual(NetworkStatus.cellularType(currentRadio: nil), .cellular(radioType: .notdeterminedcellular))
    }

    func test_the_network_monitor_answers_without_blocking() {
        // Read off the main thread: a read that blocked would never fulfil it.
        let answered = expectation(description: "answered")
        DispatchQueue.global().async {
            _ = NetworkStatus.nManager.connectionStatus
            answered.fulfill()
        }
        wait(for: [answered], timeout: 10)
    }

    func test_a_cellular_path_without_a_radio_is_online_over_cellular() {
        let source = FakePathSource()
        let status = NetworkStatus(source: source)
        source.deliver(.cellular(radio: nil))

        XCTAssertEqual(status.connectionStatus, .Online)
        XCTAssertEqual(status.connectionType, .cellular(radioType: .notdeterminedcellular))
    }

    func test_before_the_first_path_the_status_is_online_and_reading_does_not_wait() {
        let source = FakePathSource()
        let status = NetworkStatus(source: source)
        // The first path, offline, comes only once the read returned — or, should the read wait for a
        // path, after a while: then the read would say offline.
        let read = DispatchSemaphore(value: 0)
        let delivered = expectation(description: "the first path")
        DispatchQueue.global().async {
            _ = read.wait(timeout: .now() + 5)
            source.deliver(.offline)
            delivered.fulfill()
        }

        XCTAssertEqual(status.connectionStatus, .Online, "unknown counts as online, at once")
        XCTAssertNil(status.connectionType)
        XCTAssertFalse(status.hasPath)
        read.signal()
        wait(for: [delivered], timeout: 10)
        XCTAssertEqual(status.connectionStatus, .Offline)
    }

    func test_a_path_that_is_not_satisfied_is_offline_and_a_late_one_brings_it_back() {
        let source = FakePathSource()
        let status = NetworkStatus(source: source)
        source.deliver(.offline)
        XCTAssertEqual(status.connectionStatus, .Offline)
        XCTAssertNil(status.connectionType)

        source.deliver(.wifi)
        XCTAssertEqual(status.connectionStatus, .Online)
        XCTAssertEqual(status.connectionType, .wifi)
    }

    func test_observers_come_and_go_on_any_thread_while_paths_arrive() {
        let source = FakePathSource()
        let status = NetworkStatus(source: source)
        let observers = (0..<50).map { _ in CountingObserver() }

        let paths = DispatchQueue(label: "paths")
        let delivered = expectation(description: "paths")
        paths.async {
            for index in 0..<2_000 {
                source.deliver(index % 2 == 0 ? .offline : .wifi)
            }
            delivered.fulfill()
        }
        DispatchQueue.concurrentPerform(iterations: 2_000) { index in
            let observer = observers[index % observers.count]
            if index % 2 == 0 {
                status.addObserver(observer: observer)
            } else {
                status.removeObserver(observer: observer)
            }
        }
        wait(for: [delivered], timeout: 10)

        XCTAssertTrue(observers.contains { $0.calls > 0 })
    }

    func test_an_observer_hears_online_once_when_the_first_path_is_online() {
        let source = FakePathSource()
        let status = NetworkStatus(source: source)
        let observer = RecordingObserver()

        status.addObserver(observer: observer)
        source.deliver(.wifi)
        source.deliver(.offline)
        source.deliver(.wifi)

        XCTAssertEqual(observer.statuses, [.Online, .Offline, .Online], "unknown was told as online: the first online path is no change")
        XCTAssertEqual(observer.types, [nil, .wifi, nil, .wifi])
    }

    func test_a_new_observer_never_hears_its_first_state_after_a_newer_one() {
        for _ in 0..<300 {
            let source = FakePathSource()
            let status = NetworkStatus(source: source)
            source.deliver(.offline)
            let observer = RecordingObserver()
            let both = DispatchGroup()
            DispatchQueue.global().async(group: both) { status.addObserver(observer: observer) }
            DispatchQueue.global().async(group: both) { source.deliver(.wifi) }
            both.wait()
            XCTAssertEqual(observer.statuses.last, status.connectionStatus, "the last state an observer heard is the current one")
        }
    }

    func test_an_observer_that_waits_for_the_main_thread_does_not_block_one_added_on_it() {
        let source = FakePathSource()
        let status = NetworkStatus(source: source)
        let waiting = MainSyncObserver()
        status.addObserver(observer: waiting)
        waiting.armed = true

        // A path comes on another thread; its observer waits for the main thread, which meanwhile adds
        // an observer of its own.
        let delivered = expectation(description: "delivered")
        DispatchQueue.global().async {
            source.deliver(.offline)
            delivered.fulfill()
        }
        XCTAssertEqual(waiting.entered.wait(timeout: .now() + 5), .success)
        let added = RecordingObserver()
        status.addObserver(observer: added)
        wait(for: [delivered], timeout: 5)
        XCTAssertEqual(added.statuses.last, .Offline)
    }

    func test_the_system_connectivity_monitor_reports_the_state_at_once_and_stops_when_cancelled() {
        var reports: [Bool] = []
        let subscription = SystemConnectivityMonitor.shared.observe { reports.append($0) }
        XCTAssertEqual(reports.count, 1, "the current state comes at once")
        subscription.cancel()
    }

    // MARK: - Helpers

    private func assertNotJSONFailure(_ outcome: Result<Void, SdkError>?, file: StaticString = #filePath, line: UInt = #line) {
        guard case let .failure(.custom(message))? = outcome else {
            return XCTFail("expected a failure, got \(String(describing: outcome))", file: file, line: line)
        }
        XCTAssertTrue(message.contains("not valid JSON"), message, file: file, line: line)
    }
}

/// Network paths sent by the test, on the caller's thread.
final class FakePathSource: NetworkPathSource {
    private var handler: ((NetworkPathSnapshot) -> Void)?
    func start(_ handler: @escaping (NetworkPathSnapshot) -> Void) { self.handler = handler }
    func cancel() { handler = nil }
    func deliver(_ path: NetworkPathSnapshot) { handler?(path) }
}

extension NetworkPathSnapshot {
    static let offline = NetworkPathSnapshot(isSatisfied: false, usesCellular: false, usesWifi: false, usesWiredEthernet: false, cellularRadio: nil)
    static let wifi = NetworkPathSnapshot(isSatisfied: true, usesCellular: false, usesWifi: true, usesWiredEthernet: false, cellularRadio: nil)
    static func cellular(radio: String?) -> NetworkPathSnapshot {
        NetworkPathSnapshot(isSatisfied: true, usesCellular: true, usesWifi: false, usesWiredEthernet: false, cellularRadio: radio)
    }
}

/// Counts the calls it gets; safe from any thread.
final class CountingObserver: NetworkStatusObserver {
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    func didChangeConnectionStatus(_ status: NetworkConnectionStatus) { lock.lock(); count += 1; lock.unlock() }
    func didChangeConnectionType(_ type: NetworkConnectionType?) { lock.lock(); count += 1; lock.unlock() }
}

/// Records what an observer of `NetworkStatus` hears, in order.
final class RecordingObserver: NetworkStatusObserver {
    private let lock = NSLock()
    private var heardStatuses: [NetworkConnectionStatus] = []
    private var heardTypes: [NetworkConnectionType?] = []
    var statuses: [NetworkConnectionStatus] { lock.lock(); defer { lock.unlock() }; return heardStatuses }
    var types: [NetworkConnectionType?] { lock.lock(); defer { lock.unlock() }; return heardTypes }
    func didChangeConnectionStatus(_ status: NetworkConnectionStatus) { lock.lock(); heardStatuses.append(status); lock.unlock() }
    func didChangeConnectionType(_ type: NetworkConnectionType?) { lock.lock(); heardTypes.append(type); lock.unlock() }
}

/// Waits for the main thread from its callback once armed.
final class MainSyncObserver: NetworkStatusObserver {
    var armed = false
    let entered = DispatchSemaphore(value: 0)
    func didChangeConnectionStatus(_ status: NetworkConnectionStatus) {
        guard armed, !Thread.isMainThread else { return }
        entered.signal()
        DispatchQueue.main.sync {}
    }
    func didChangeConnectionType(_ type: NetworkConnectionType?) {}
}
