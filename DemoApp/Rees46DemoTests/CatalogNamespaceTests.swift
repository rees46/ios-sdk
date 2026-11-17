//
//  CatalogNamespaceTests.swift
//  REES46Tests
//
//  The catalog's namespaces end to end over the stub server — `products`, `collections`,
//  `recommendations` and the search of `search` —: each method sends its request with the common fields
//  and reads the answer, in `completion` and in `async` code; on the old core each one is
//  `notInitialized`, sends nothing and logs its name; a refused argument sends nothing. The cases of
//  each request and answer are the package's (`CatalogPackageTests`).
//

import XCTest
@_spi(Bridge) @testable import REES46

final class CatalogNamespaceTests: CoreScenarioTestCase {

    /// One method of the catalog, called with arguments it sends.
    private struct Method {
        /// What the log calls it.
        let name: String
        /// The stub's path of its request.
        let path: String
        /// The fields of the query it sends for these arguments.
        let sends: [String: String]
        /// An answer it reads.
        let answer: String
        let call: (PersonalizationSDK, @escaping (Rees46.SdkError?) -> Void) -> Void
        let callAsync: (PersonalizationSDK) async throws -> Void
    }

    private let methods: [Method] = [
        Method(
            name: "products.getInfo", path: "/products/get", sends: ["item_id": "37"],
            answer: #"{"id": "37", "uniqid": "37", "name": "Phone", "url": "https://shop.example/37", "price": "99", "currency": "$"}"#,
            call: { sdk, done in sdk.products.getInfo(itemId: "37") { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.products.getInfo(itemId: "37") }
        ),
        Method(
            name: "products.getList", path: "/products", sends: ["limit": "5", "sort_by": "price"],
            answer: #"{"products_total": 0, "products": []}"#,
            call: { sdk, done in sdk.products.getList(Rees46.ProductsListRequest(sortBy: .price, limit: 5)) { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.products.getList(Rees46.ProductsListRequest(sortBy: .price, limit: 5)) }
        ),
        Method(
            name: "products.getCounters", path: "/products/counters", sends: ["item": "37"],
            answer: #"{"daily": {"view": 1, "cart": 0, "purchase": 0}}"#,
            call: { sdk, done in sdk.products.getCounters(itemId: "37") { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.products.getCounters(itemId: "37") }
        ),
        Method(
            name: "products.getCategory", path: "/products", sends: ["categories": "15"],
            answer: #"{"products": []}"#,
            call: { sdk, done in sdk.products.getCategory(categoryId: "15") { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.products.getCategory(categoryId: "15") }
        ),
        Method(
            name: "collections.get", path: "/collection/12", sends: [:],
            answer: #"{"products": []}"#,
            call: { sdk, done in sdk.collections.get(collectionId: "12") { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.collections.get(collectionId: "12") }
        ),
        Method(
            name: "recommendations.get", path: "/recommend/block-1", sends: ["extended": "true", "item_id": "37"],
            answer: #"{"id": 1, "title": "Similar", "recommends": []}"#,
            call: { sdk, done in sdk.recommendations.get(code: "block-1", request: Rees46.RecommendationRequest(itemId: "37")) { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.recommendations.get(code: "block-1", request: Rees46.RecommendationRequest(itemId: "37")) }
        ),
        Method(
            name: "search.blank", path: "/search/blank", sends: [:],
            answer: #"{"last_products": false}"#,
            call: { sdk, done in sdk.search.blank { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.search.blank() }
        ),
        Method(
            name: "search.instant", path: "/search", sends: ["type": "instant_search", "search_query": "phone"],
            answer: #"{"products": []}"#,
            call: { sdk, done in sdk.search.instant(query: "phone") { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.search.instant(query: "phone") }
        ),
        Method(
            name: "search.full", path: "/search", sends: ["type": "full_search", "search_query": "phone", "page": "2"],
            answer: #"{"products": []}"#,
            call: { sdk, done in sdk.search.full(query: "phone", request: Rees46.SearchFullRequest(page: 2)) { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.search.full(query: "phone", request: Rees46.SearchFullRequest(page: 2)) }
        ),
    ]

    /// How `method` ended with `completion`, which comes on the main thread.
    private func outcome(_ method: Method, _ sdk: PersonalizationSDK, file: StaticString = #filePath, line: UInt = #line) -> Rees46.SdkError? {
        let done = expectation(description: method.name)
        let error = Locked<Rees46.SdkError?>(nil)
        method.call(sdk) { failure in
            XCTAssertTrue(Thread.isMainThread, "\(method.name): completion on the main thread", file: file, line: line)
            error.current = failure
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return error.current
    }

    /// How `method` ended in `async` code.
    private func asyncOutcome(_ method: Method, _ sdk: PersonalizationSDK) -> Rees46.SdkError? {
        let done = expectation(description: "async \(method.name)")
        let error = Locked<Rees46.SdkError?>(nil)
        _Concurrency.Task {
            do {
                try await method.callAsync(sdk)
            } catch let failure as Rees46.SdkError {
                error.current = failure
            } catch {
                XCTFail("\(method.name): not an SdkError: \(error)")
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return error.current
    }

    // MARK: - The new core

    func test_each_method_sends_its_request_with_the_common_fields_and_reads_the_answer() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        for method in methods {
            answer(method.path, StubReply(json: method.answer))
            let before = requests(method.path, shop).count
            XCTAssertNil(outcome(method, sdk), method.name)
            let sent = requests(method.path, shop)
            XCTAssertEqual(sent.count, before + 1, "\(method.name): one request")
            let request = try XCTUnwrap(sent.last, method.name)
            XCTAssertEqual(request.method, "GET", method.name)
            for (key, value) in method.sends {
                XCTAssertEqual(request.query[key], value, "\(method.name): \(key)")
            }
            XCTAssertEqual(request.query["shop_id"], shop, method.name)
            XCTAssertEqual(request.query["did"], "d", method.name)
            XCTAssertEqual(request.query["sid"], sdk.sessionId, method.name)
            XCTAssertEqual(request.query["seance"], sdk.sessionId, method.name)
            XCTAssertEqual(request.query["stream"], "ios", method.name)
            XCTAssertEqual(request.query["segment"], sdk.segment, method.name)
            XCTAssertEqual(request.timeout, NetworkClient.defaultTimeout, method.name)
        }
        sdk.release()
    }

    func test_each_method_returns_its_value_in_async_code() {
        let shop = newShop()
        let sdk = makeV2(shop)
        for method in methods {
            answer(method.path, StubReply(json: method.answer))
            XCTAssertNil(asyncOutcome(method, sdk), method.name)
        }
        answer("/recommend/block-1", StubReply(404, json: #"{"status": "error", "message": "not found"}"#))
        XCTAssertEqual(asyncOutcome(methods[5], sdk), .http(code: 404, serverCode: nil))
        sdk.release()
    }

    func test_the_values_come_whole_through_the_core() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/products/get", StubReply(json: #"{"id": "1", "uniqid": "A-1", "name": "Phone", "url": "u", "price": "99.5", "oldprice": 0, "currency": "$"}"#))
        let done = expectation(description: "products.getInfo")
        let product = Locked<Rees46.Product?>(nil)
        sdk.products.getInfo(itemId: "A-1") { result in
            product.current = (try? result.get()) ?? nil
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(product.current?.id, "A-1")
        XCTAssertEqual(product.current?.price, 99.5)
        XCTAssertNil(product.current?.oldPrice)
        sdk.release()
    }

    func test_a_collection_id_and_a_block_code_go_encoded_in_the_path() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/collection/a/b c", StubReply(json: #"{"products": []}"#))
        let collection = expectation(description: "collections.get")
        sdk.collections.get(collectionId: "a/b c") { result in
            XCTAssertNotNil(try? result.get())
            collection.fulfill()
        }
        let block = expectation(description: "recommendations.get")
        sdk.recommendations.get(code: "блок 1") { _ in block.fulfill() }
        wait(for: [collection, block], timeout: 5)
        XCTAssertEqual(requests("/collection/a/b c", shop).last?.url?.absoluteString.contains("/collection/a%2Fb%20c?"), true)
        XCTAssertEqual(requests("/recommend/блок 1", shop).last?.url?.absoluteString.contains("/recommend/%D0%B1%D0%BB%D0%BE%D0%BA%201?"), true)
        sdk.release()
    }

    func test_a_refused_argument_sends_nothing_and_is_logged_with_the_call() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let done = expectation(description: "refused")
        done.expectedFulfillmentCount = 3
        let errors = Locked<[Rees46.SdkError]>([])
        sdk.products.getInfo(itemId: " ") { result in
            if case .failure(let error) = result { errors.mutate { $0.append(error) } }
            done.fulfill()
        }
        sdk.search.full(query: "phone", request: Rees46.SearchFullRequest(limit: 0)) { result in
            if case .failure(let error) = result { errors.mutate { $0.append(error) } }
            done.fulfill()
        }
        sdk.recommendations.get(code: "b", request: Rees46.RecommendationRequest(extended: false, withLocations: true)) { result in
            if case .failure(let error) = result { errors.mutate { $0.append(error) } }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(errors.current.count, 3)
        XCTAssertTrue(errors.current.allSatisfy { if case .invalidArgument = $0 { return true } else { return false } }, "\(errors.current)")
        XCTAssertTrue(requests("/products/get", shop).isEmpty)
        XCTAssertTrue(requests("/search", shop).isEmpty)
        XCTAssertTrue(requests("/recommend/b", shop).isEmpty)
        XCTAssertTrue(waitForLog(shop, "invalid_argument"))
        XCTAssertTrue(eventually { Set(self.logged(shop, "invalid_argument").compactMap { $0.context["call"] }).isSuperset(of: ["products.getInfo", "search.full", "recommendations.get"]) })
        sdk.release()
    }

    // MARK: - The old core

    func test_on_the_old_core_each_method_is_not_initialized_sends_nothing_and_logs_its_name() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        for method in methods {
            XCTAssertEqual(outcome(method, sdk), .notInitialized, method.name)
            XCTAssertEqual(asyncOutcome(method, sdk), .notInitialized, method.name)
            XCTAssertTrue(requests(method.path, shop).isEmpty, method.name)
        }
        XCTAssertTrue(waitForLog(shop, "core_flag_mismatch"))
        let names = Set(methods.map(\.name))
        XCTAssertTrue(eventually { Set(self.logged(shop, "core_flag_mismatch").compactMap { $0.context["call"] }) == names })
        XCTAssertTrue(logged(shop, "core_flag_mismatch").allSatisfy { $0.level == .warning })
        sdk.release()
    }

    func test_another_conformer_of_the_protocol_is_not_initialized() {
        let fake = FakeSDK(shopId: "fake-\(UUID().uuidString)")
        for method in methods {
            XCTAssertEqual(outcome(method, fake), .notInitialized, method.name)
        }
    }
}

private extension Result {

    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
