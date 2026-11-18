//
//  FixtureMatching.swift
//  REES46CoreTests
//
//  How the package tests hold a namespace's method to the cases of a fixture without a server: the
//  request it builds against the case's `request`, and its value of an answer — read by the namespaces'
//  one request path — against the case's `expect`.
//

import XCTest
@testable import REES46

/// A case of a fixture with what `ContractCase` does not keep: the lists of a query (`promo_codes[]`).
struct FixtureCase {
    let item: ContractCase
    /// The case's `request.query` as it is in the file.
    let rawQuery: [String: Any]

    var name: String { item.name }
    var args: [String: Any] { item.call?.args ?? [:] }
    var method: String { item.call?.method ?? "" }

    static func load(_ name: String) throws -> [FixtureCase] {
        let raw = try ContractFixtures.cases(name, from: .proposed)
        return raw.map { json in
            FixtureCase(
                item: ContractCase(json),
                rawQuery: (json["request"] as? [String: Any])?["query"] as? [String: Any] ?? [:]
            )
        }
    }
}

enum FixtureMatching {

    /// `request` is the one the case names: its method and path, and every field it lists — a query's
    /// list included —; fields it does not list are not checked.
    static func assert(_ request: CoreRequest, is item: FixtureCase, file: StaticString = #filePath, line: UInt = #line) {
        guard let expected = item.item.request else {
            return XCTFail("\(item.name): the case names no request", file: file, line: line)
        }
        XCTAssertEqual(request.method.rawValue, expected.method, item.name, file: file, line: line)
        XCTAssertEqual(request.path, expected.path, item.name, file: file, line: line)
        for (key, value) in item.rawQuery {
            if let list = value as? [String] {
                XCTAssertEqual(request.queryLists[key], list, "\(item.name): \(key)", file: file, line: line)
            } else {
                XCTAssertEqual(request.query[key], "\(value)", "\(item.name): \(key)", file: file, line: line)
            }
        }
        for (key, value) in expected.body {
            let problems = mismatches(request.body[key], value, at: key)
            XCTAssertTrue(problems.isEmpty, "\(item.name): \(problems)", file: file, line: line)
        }
    }

    /// `make` refuses the case's call with its error, so nothing is sent.
    static func assertRefused<T>(_ item: FixtureCase, file: StaticString = #filePath, line: UInt = #line, _ make: () throws -> T) {
        do {
            _ = try make()
            XCTFail("\(item.name): built, expected \(String(describing: item.item.expectedError))", file: file, line: line)
        } catch let error as Rees46.SdkError {
            XCTAssertTrue(item.item.expectedError?.matches(error) == true, "\(item.name): \(error)", file: file, line: line)
        } catch {
            XCTFail("\(item.name): not an SdkError: \(error)", file: file, line: line)
        }
    }

    /// What the method ends with for the case's answer, read as the namespaces read every answer.
    static func outcome<Value>(of item: FixtureCase, for request: ApiRequest<Value>, call: String) throws -> Result<Value, Rees46.SdkError> {
        let response = try XCTUnwrap(item.item.response, item.name)
        let status = try XCTUnwrap(response.status, item.name)
        let answer = NetworkClient.Response(
            status: status, body: response.body, retryAfter: nil,
            result: NetworkClient.classify(status: status, body: response.body, path: request.path)
        )
        let logger = SdkLogger(shopId: "package-\(UUID().uuidString)", level: .none)
        return NamespaceRequests.value(of: answer, for: request, call: call, logger: logger)
    }

    /// `result` ends as the case expects: its error, or a value whose JSON by the contract's names (`json`)
    /// has what `expect.result` lists.
    static func assert<Value>(
        _ result: Result<Value, Rees46.SdkError>,
        as item: FixtureCase,
        json: (Value) -> Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch result {
        case .success(let value):
            XCTAssertNil(item.item.expectedError, "\(item.name): \(value)", file: file, line: line)
            let problems = mismatches(json(value), item.item.expect["result"], at: "result")
            XCTAssertTrue(problems.isEmpty, "\(item.name): \(problems)", file: file, line: line)
        case .failure(let error):
            XCTAssertTrue(
                item.item.expectedError?.matches(error) == true,
                "\(item.name): \(error), expected \(String(describing: item.item.expectedError))",
                file: file, line: line
            )
        }
    }

    /// Where `actual` differs from `expected`: an object of `expected` lists the fields to check, a list
    /// has as many elements in the same order, `null` is no value, numbers and booleans compare by value.
    static func mismatches(_ actual: Any?, _ expected: Any?, at path: String) -> [String] {
        let actual = actual.flatMap { $0 is NSNull ? nil : $0 }
        switch expected {
        case nil, is NSNull:
            return actual == nil ? [] : ["\(path): \(String(describing: actual)), expected none"]
        case let object as [String: Any]:
            guard let fields = actual as? [String: Any] else { return ["\(path): \(String(describing: actual)), expected an object"] }
            return object.keys.sorted().flatMap { mismatches(fields[$0], object[$0], at: "\(path).\($0)") }
        case let list as [Any]:
            guard let elements = actual as? [Any] else { return ["\(path): \(String(describing: actual)), expected a list"] }
            guard elements.count == list.count else { return ["\(path): \(elements.count) elements, expected \(list.count)"] }
            return zip(elements, list).enumerated().flatMap { mismatches($0.element.0, $0.element.1, at: "\(path)[\($0.offset)]") }
        case let number as NSNumber:
            guard let value = actual as? NSNumber, abs(value.doubleValue - number.doubleValue) < 1e-9 else {
                return ["\(path): \(String(describing: actual)), expected \(number)"]
            }
            return []
        case let text as String:
            return actual as? String == text ? [] : ["\(path): \(String(describing: actual)), expected \(text)"]
        default:
            return ["\(path): cannot compare \(String(describing: expected))"]
        }
    }

    /// `value`, or `NSNull` for none: a field of a result's JSON.
    static func field(_ value: Any?) -> Any {
        value ?? NSNull()
    }
}
