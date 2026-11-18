//
//  NamespaceFixtures.swift
//  REES46CoreTests
//
//  Runs a namespace's fixture without a server: the request each call builds, the error a refused one
//  ends with before anything is sent, and what the request path makes of each answer. A fixture's
//  `result` is the method's value by the contract's field names, and `request.query` or `request.body`
//  the request's own fields; both are compared whole, as the Android SDK compares them: a field without
//  a value is left out on either side. A server method's case lists the common fields its request
//  carries (`request.commonFields`); they are the ones the client adds to the request it built.
//

import XCTest
@_spi(Bridge) @testable import REES46

/// A namespace's request, built from a fixture's call, its value's type erased.
struct ErasedRequest {
    let method: String
    let path: String
    let query: [String: String]
    let body: [String: Any]
    let timeout: TimeInterval?
    /// A server method's request (`SecretQuery`): the client adds `shop_id` alone.
    let secret: Bool
    /// What the request path makes of `response`: the value as JSON by the contract's names, or the
    /// error.
    let answer: (NetworkClient.Response, SdkLogger) -> Result<Any, Rees46.SdkError>

    init<Value>(_ request: ApiRequest<Value>, call: String) {
        method = request.method.rawValue
        path = request.path
        query = request.query
        body = request.body
        timeout = request.timeout
        secret = request.secret
        answer = { response, logger in
            NamespaceRequests.value(of: response, for: request, call: call, logger: logger).map { ContractJSON.of($0) }
        }
    }
}

enum NamespaceFixtures {

    /// Builds the request of a fixture's call; throws what the method refuses.
    typealias Build = (ContractCase.Call) throws -> ErasedRequest

    /// The common fields of every request (`sdk/core/network.md`).
    static let commonFieldNames: Set<String> = ["shop_id", "did", "sid", "seance", "segment", "stream"]

    /// The common fields of a device the shop knows, each with a value: what the client adds shows.
    private static let commonFields = CommonFields(shopId: "shop-1", deviceId: "did-1", sessionId: "sid-1", stream: "ios", segment: "B")

    /// Whether `json`, a case of a fixture, is for iOS and calls one of `methods` (any, when `nil`).
    private static func takes(_ json: [String: Any], _ methods: Set<String>?) -> Bool {
        let method = (json["call"] as? [String: Any])?["method"] as? String ?? ""
        return (json["platform"] as? String ?? "ios") == "ios" && methods.map { $0.contains(method) } ?? true
    }

    /// Every case of `name` with a request or an error instead of one: the call builds that request, or
    /// throws that error. `methods`: the cases of these methods alone.
    static func checkRequests(
        _ name: String,
        methods: Set<String>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line,
        build: Build
    ) throws {
        let raw = try ContractFixtures.cases(name, from: .proposed).filter { takes($0, methods) }
        let cases = raw.map(ContractCase.init)
        var checked = 0
        for (json, item) in zip(raw, cases) {
            guard let call = item.call, item.response == nil else { continue }
            if let expected = json["request"] as? [String: Any] {
                checked += 1
                let request: ErasedRequest
                do {
                    request = try build(call)
                } catch {
                    XCTFail("\(item.name): \(error)", file: file, line: line)
                    continue
                }
                XCTAssertEqual(request.method, expected["method"] as? String, item.name, file: file, line: line)
                XCTAssertEqual(request.path, expected["path"] as? String, item.name, file: file, line: line)
                // The request's own fields, all of them: the core adds the common ones.
                let own: [String: Any] = request.method == "GET" ? request.query : request.body
                let wanted = expected[request.method == "GET" ? "query" : "body"] as? [String: Any] ?? [:]
                for problem in ContractJSON.mismatches(ContractJSON.of(own), wanted, at: "request") {
                    XCTFail("\(item.name): \(problem)", file: file, line: line)
                }
                if let common = item.request?.commonFields {
                    checkCommonFields(of: request, are: Set(common), listed: wanted, item.name, file: file, line: line)
                }
            } else if let error = item.expectedError {
                checked += 1
                do {
                    let request = try build(call)
                    XCTFail("\(item.name): built \(request.method) \(request.path), expected \(error)", file: file, line: line)
                } catch let refusal as Rees46.SdkError {
                    XCTAssertTrue(error.matches(refusal), "\(item.name): \(refusal), expected \(error)", file: file, line: line)
                }
            }
        }
        XCTAssertGreaterThan(checked, 0, "\(name) has calls", file: file, line: line)
    }

    /// Of the common fields, `request` goes with `common` alone once the client adds them, as
    /// `NetworkClient` does; a common field the case lists among the request's own (`listed`) is the
    /// method's, given by the caller, and keeps its value.
    private static func checkCommonFields(
        of request: ErasedRequest,
        are common: Set<String>,
        listed: [String: Any],
        _ name: String,
        file: StaticString,
        line: UInt
    ) {
        let sent: [String: Any]
        if request.method == "GET" {
            sent = commonFields.apply(to: request.query, path: request.path, onlyShop: request.secret)
        } else {
            sent = commonFields.apply(to: request.body, path: request.path, onlyShop: request.secret)
        }
        let mine = Set(listed.keys)
        XCTAssertEqual(
            Set(sent.keys).intersection(commonFieldNames).subtracting(mine), common.subtracting(mine),
            "\(name): the common fields", file: file, line: line
        )
        for key in mine.intersection(commonFieldNames) {
            for problem in ContractJSON.mismatches(ContractJSON.of(sent[key] ?? NSNull()), listed[key] ?? NSNull(), at: key) {
                XCTFail("\(name): \(problem)", file: file, line: line)
            }
        }
    }

    /// Every case of `name` with an answer: the request of its call ends with the case's result or error,
    /// as the client classifies the answer and the request path reads it. `methods`: the cases of these
    /// methods alone. The result of a method of `listed` is held to the fields its case lists
    /// (`FixtureMatching`): a file compared whole names the methods whose released model the platforms
    /// name differently (`profile.getOrders`).
    static func checkAnswers(
        _ name: String,
        methods: Set<String>? = nil,
        listed: Set<String> = [],
        file: StaticString = #filePath,
        line: UInt = #line,
        build: Build
    ) throws {
        let logger = SdkLogger(shopId: "package-\(UUID().uuidString)", level: .none)
        let cases = try ContractFixtures.cases(name, from: .proposed)
            .filter { takes($0, methods) }
            .map(ContractCase.init)
            .filter { $0.response != nil }
        XCTAssertFalse(cases.isEmpty, "\(name) has answers", file: file, line: line)
        for item in cases {
            guard let call = item.call, let response = item.response else { continue }
            let request: ErasedRequest
            do {
                request = try build(call)
            } catch {
                XCTFail("\(item.name): \(error)", file: file, line: line)
                continue
            }
            let answer = NetworkClient.Response(
                status: response.status,
                body: response.body,
                retryAfter: nil,
                // No status: no answer, a connection never made.
                result: response.status.map { NetworkClient.classify(status: $0, body: response.body, path: request.path) } ?? .failure(.network)
            )
            switch request.answer(answer, logger) {
            case .success(let value):
                XCTAssertNil(item.expectedError, "\(item.name): \(value)", file: file, line: line)
                guard item.expectedError == nil else { continue }
                guard let expected = item.expect["result"] else {
                    XCTFail("\(item.name): the case has no result", file: file, line: line)
                    continue
                }
                let problems = listed.contains(call.method)
                    ? FixtureMatching.mismatches(value, expected, at: "result")
                    : ContractJSON.mismatches(value, expected, at: "result")
                for problem in problems {
                    XCTFail("\(item.name): \(problem)", file: file, line: line)
                }
            case .failure(let error):
                XCTAssertTrue(item.expectedError?.matches(error) == true, "\(item.name): \(error), expected \(String(describing: item.expectedError))", file: file, line: line)
            }
        }
    }

    // MARK: - Arguments

    static func string(_ value: Any?) -> String? {
        value as? String
    }

    static func strings(_ value: Any?) -> [String]? {
        (value as? [Any])?.map { "\($0)" }
    }

    static func int(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    static func double(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    static func bool(_ value: Any?) -> Bool? {
        (value as? NSNumber)?.boolValue
    }

    static func filters(_ value: Any?) -> [String: [String]]? {
        (value as? [String: Any])?.mapValues { strings($0) ?? [] }
    }

    /// A key of sorting by its name in the contract's code: `salesRate`.
    static func sortBy(_ value: Any?) -> Rees46.SortBy? {
        guard let name = value as? String else { return nil }
        let known: [String: Rees46.SortBy] = [
            "price": .price, "discount": .discount, "salesRate": .salesRate, "date": .date,
            "priceMargin": .priceMargin, "rating": .rating, "relevance": .relevance
        ]
        return known[name] ?? Rees46.SortBy(rawValue: name)
    }

    static func sortDir(_ value: Any?) -> Rees46.SortDirection? {
        (value as? String).flatMap(Rees46.SortDirection.init(rawValue:))
    }
}

/// A value of the SDK as the JSON a fixture writes it by the contract's names, and the comparison of
/// the two.
enum ContractJSON {

    /// `value` as JSON: a model is an object of its properties — named as the contract names its
    /// fields —, a list a list, a map an object, `nil` `NSNull`, a value of an open or closed set its
    /// raw value.
    static func of(_ value: Any) -> Any {
        if let text = value as? String {
            return text
        }
        // A boolean, Swift's or JSON's, is one; any other number — `Int`, `Double`, `NSNumber` — its value.
        if let number = value as? NSNumber {
            return CFGetTypeID(number) == CFBooleanGetTypeID() ? number.boolValue as Any : number.doubleValue
        }
        if value is NSNull {
            return NSNull()
        }
        // Lists and maps, Swift's or JSON's.
        if let list = value as? [Any] {
            return list.map(of)
        }
        if let map = value as? [String: Any] {
            return map.mapValues(of)
        }
        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .tuple where mirror.children.isEmpty:
            // `Void`: a method without a value.
            return NSNull()
        case .optional:
            return mirror.children.first.map { of($0.value) } ?? NSNull()
        case .collection, .set:
            return mirror.children.map { of($0.value) }
        case .dictionary:
            var object: [String: Any] = [:]
            for entry in mirror.children {
                let pair = Mirror(reflecting: entry.value).children.map(\.value)
                if pair.count == 2 {
                    object["\(pair[0])"] = of(pair[1])
                }
            }
            return object
        default:
            if let raw = value as? any RawRepresentable {
                return of(raw.rawValue)
            }
            var object: [String: Any] = [:]
            for child in mirror.children {
                if let label = child.label {
                    object[label] = of(child.value)
                }
            }
            return object
        }
    }

    /// Where `actual` differs from `expected`, as the Android SDK compares them: an object has the same
    /// fields with a value — a field whose value is `null` counts as missing on either side —, each the
    /// same; a list the same elements in order; a number the same value, `19990` as `19990.0`.
    static func mismatches(_ actual: Any, _ expected: Any, at path: String) -> [String] {
        switch expected {
        case is NSNull:
            return actual is NSNull ? [] : ["\(path): \(actual), expected null"]
        case let object as [String: Any]:
            guard let actualObject = actual as? [String: Any] else {
                return ["\(path): \(actual), expected an object"]
            }
            let wanted = Set(object.filter { !($0.value is NSNull) }.keys)
            let got = Set(actualObject.filter { !($0.value is NSNull) }.keys)
            var problems: [String] = []
            if wanted != got {
                problems.append("\(path): fields \(got.sorted()), expected \(wanted.sorted())")
            }
            for key in wanted.intersection(got).sorted() {
                problems += mismatches(actualObject[key] ?? NSNull(), object[key] ?? NSNull(), at: "\(path).\(key)")
            }
            return problems
        case let list as [Any]:
            guard let actualList = actual as? [Any] else {
                return ["\(path): \(actual), expected a list"]
            }
            guard actualList.count == list.count else {
                return ["\(path): \(actualList.count) elements, expected \(list.count): \(actualList)"]
            }
            return zip(actualList, list).enumerated().flatMap { index, pair in
                mismatches(pair.0, pair.1, at: "\(path)[\(index)]")
            }
        case let text as String:
            return actual as? String == text ? [] : ["\(path): \(actual), expected \"\(text)\""]
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return actual as? Bool == number.boolValue ? [] : ["\(path): \(actual), expected \(number.boolValue)"]
            }
            let value: Double?
            switch actual {
            case let int as Int: value = Double(int)
            case let double as Double: value = double
            default: value = nil
            }
            guard let found = value, abs(found - number.doubleValue) < 1e-9 else {
                return ["\(path): \(actual), expected \(number)"]
            }
            return []
        default:
            return ["\(path): cannot compare \(expected)"]
        }
    }
}
