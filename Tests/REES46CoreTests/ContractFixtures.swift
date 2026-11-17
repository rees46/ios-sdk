//
//  ContractFixtures.swift
//  REES46CoreTests, REES46Tests
//
//  The contract's shared fixtures (`sdk/fixtures/*.json`, `sdk/fixtures/README.md`): the package tests
//  and the demo app's tests compile this one file. The contract's files are in
//  `Fixtures/contract-<version>/` as they are; `Fixtures/proposed/` holds the SDK's cases, in the same
//  format, for a namespace the contract has no file for yet.
//

import Foundation
@testable import REES46

enum ContractFixtures {

    /// The version of the contract the copies are of.
    static let version = "0"

    enum Source {
        /// `sdk/fixtures` of the contract, copied as it is.
        case contract
        /// The SDK's own cases in the contract's format, until the contract has the namespace's file.
        case proposed

        var folder: String {
            switch self {
            case .contract: return "contract-\(ContractFixtures.version)"
            case .proposed: return "proposed"
            }
        }
    }

    /// The file `name` of `source`, next to this file in the repository.
    static func url(_ name: String, extension type: String = "json", from source: Source = .contract) -> URL {
        URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(source.folder)/\(name).\(type)")
    }

    static func load(_ name: String, from source: Source = .contract) throws -> [String: Any] {
        let data = try Data(contentsOf: url(name, from: source))
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    static func cases(_ name: String, from source: Source = .contract) throws -> [[String: Any]] {
        try load(name, from: source)["cases"] as? [[String: Any]] ?? []
    }

    /// The cases of `name`, typed.
    static func fixture(_ name: String, from source: Source = .contract) throws -> [ContractCase] {
        try cases(name, from: source).map(ContractCase.init)
    }
}

/// One case of a fixture: a call and the request it sends, or an error instead of it; or the answer the
/// server gives and what the method ends with.
struct ContractCase {

    let name: String
    /// `namespace.method` and its arguments by the contract's names.
    let call: Call?
    /// The request the call sends; only the fields listed count.
    let request: Request?
    /// The answer of the server; `status` `nil` is none (no network, a timeout).
    let response: Response?
    /// What the method ends with: `error` (`expectedError`), `result`, or a state of the core.
    let expect: [String: Any]
    /// The error the call ends with: without a request (`error` of the case), or for the answer
    /// (`expect.error`).
    let expectedError: ErrorSpec?

    struct Call {
        let namespace: String
        let method: String
        let args: [String: Any]
        var name: String { "\(namespace).\(method)" }
    }

    struct Request {
        let method: String
        /// Without the host and the leading slash.
        let path: String
        let query: [String: String]
        let body: [String: Any]
    }

    struct Response {
        let status: Int?
        /// The body as JSON; empty for `null` or none.
        let body: Data
    }

    /// An `SdkError` as a fixture names it: its `type`, and `code` for `http`.
    struct ErrorSpec: CustomStringConvertible {
        let type: String
        let code: Int?

        /// Whether `error` is this one; the message of `invalidArgument` is the SDK's own.
        func matches(_ error: Rees46.SdkError) -> Bool {
            if case .http(let actual, _) = error {
                return type == "http" && (code == nil || code == actual)
            }
            return type == ContractCase.type(of: error)
        }

        var description: String {
            code.map { "\(type) \($0)" } ?? type
        }
    }

    init(_ json: [String: Any]) {
        name = json["name"] as? String ?? "?"
        if let call = json["call"] as? [String: Any] {
            self.call = Call(
                namespace: call["namespace"] as? String ?? "",
                method: call["method"] as? String ?? "",
                args: call["args"] as? [String: Any] ?? [:]
            )
        } else {
            call = nil
        }
        if let request = json["request"] as? [String: Any] {
            self.request = Request(
                method: request["method"] as? String ?? "",
                path: request["path"] as? String ?? "",
                query: (request["query"] as? [String: Any] ?? [:]).mapValues { "\($0)" },
                body: request["body"] as? [String: Any] ?? [:]
            )
        } else {
            request = nil
        }
        if let response = json["response"] as? [String: Any] {
            let body = response["body"].flatMap { $0 is NSNull ? nil : $0 }
            self.response = Response(
                status: response["status"] as? Int,
                body: body.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: .fragmentsAllowed) } ?? Data()
            )
        } else {
            response = nil
        }
        expect = json["expect"] as? [String: Any] ?? [:]
        let error = json["error"] as? [String: Any] ?? expect["error"] as? [String: Any]
        expectedError = error.map { ErrorSpec(type: $0["type"] as? String ?? "", code: $0["code"] as? Int) }
    }

    /// The name of `error`'s case, as the fixtures write it.
    static func type(of error: Rees46.SdkError) -> String {
        switch error {
        case .notInitialized: return "notInitialized"
        case .shopBlocked: return "shopBlocked"
        case .invalidArgument: return "invalidArgument"
        case .network: return "network"
        case .timeout: return "timeout"
        case .http: return "http"
        case .decoding: return "decoding"
        case .cancelled: return "cancelled"
        }
    }
}
