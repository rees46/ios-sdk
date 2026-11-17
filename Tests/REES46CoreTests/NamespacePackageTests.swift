//
//  NamespacePackageTests.swift
//  REES46CoreTests
//
//  The base of the namespaces that needs no server: how an answer is read (`LenientDecoding`) and the
//  loader of the contract's fixtures.
//

import XCTest
@testable import REES46

final class NamespacePackageTests: XCTestCase {

    // MARK: - Reading an answer

    /// Every field of an answer, read leniently.
    private struct Sample: Decodable {
        let string: String?
        let int: Int?
        let double: Double?
        let bool: Bool?
        let kind: Kind?
        let nested: Nested?
        let list: [Nested]?

        enum Kind: String {
            case one, two
        }

        struct Nested: Decodable {
            let id: String
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: AnswerKey.self)
                guard let id = container.lenientString("id") else {
                    throw DecodingError.keyNotFound(AnswerKey("id"), DecodingError.Context(codingPath: container.codingPath, debugDescription: "no id"))
                }
                self.id = id
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: AnswerKey.self)
            string = container.lenientString("string")
            int = container.lenientInt("int")
            double = container.lenientDouble("double")
            bool = container.lenientBool("bool")
            kind = container.lenientEnum(Kind.self, "kind")
            nested = container.lenient(Nested.self, "nested")
            list = container.lenientList(Nested.self, "list")
        }
    }

    private func sample(_ json: String) throws -> Sample {
        try JSONDecoder().decode(Sample.self, from: Data(json.utf8))
    }

    func test_numbers_come_as_strings_and_strings_as_numbers() throws {
        let read = try sample(#"{"string": 37, "int": "4", "double": "12.5", "bool": "true"}"#)
        XCTAssertEqual(read.string, "37")
        XCTAssertEqual(read.int, 4)
        XCTAssertEqual(read.double, 12.5)
        XCTAssertEqual(read.bool, true)

        let numbers = try sample(#"{"string": 12.5, "int": 3.0, "double": 7, "bool": 0}"#)
        XCTAssertEqual(numbers.string, "12.5")
        XCTAssertEqual(numbers.int, 3, "a number without a fraction is an integer")
        XCTAssertEqual(numbers.double, 7)
        XCTAssertEqual(numbers.bool, false)

        let integral = try sample(#"{"string": 37.0, "int": " 5 ", "bool": 1}"#)
        XCTAssertEqual(integral.string, "37", "an integral number is its digits")
        XCTAssertEqual(integral.int, 5)
        XCTAssertEqual(integral.bool, true)
    }

    func test_a_missing_null_or_unfit_field_is_empty_not_a_failure() throws {
        let missing = try sample("{}")
        XCTAssertNil(missing.string)
        XCTAssertNil(missing.int)
        XCTAssertNil(missing.double)
        XCTAssertNil(missing.bool)
        XCTAssertNil(missing.kind)
        XCTAssertNil(missing.nested)
        XCTAssertNil(missing.list)

        let null = try sample(#"{"string": null, "int": null, "double": null, "bool": null, "kind": null, "nested": null, "list": null}"#)
        XCTAssertNil(null.string)
        XCTAssertNil(null.int)
        XCTAssertNil(null.nested)
        XCTAssertNil(null.list)

        let unfit = try sample(#"{"string": {"a": 1}, "int": 2.5, "double": "abc", "bool": "maybe", "nested": [1], "list": {"id": "1"}}"#)
        XCTAssertNil(unfit.string)
        XCTAssertNil(unfit.int, "a number with a fraction is not an integer")
        XCTAssertNil(unfit.double)
        XCTAssertNil(unfit.bool)
        XCTAssertNil(unfit.nested)
        XCTAssertNil(unfit.list)

        XCTAssertNil(try sample(#"{"string": ""}"#).string, "an empty string is no value")
        XCTAssertNil(try sample(#"{"int": "", "double": "1e999"}"#).int)
        XCTAssertNil(try sample(#"{"double": "1e999"}"#).double, "not a finite number")
    }

    func test_an_unknown_value_of_an_enumeration_is_empty_and_unknown_fields_are_ignored() throws {
        XCTAssertEqual(try sample(#"{"kind": "two"}"#).kind, .two)
        let read = try sample(#"{"kind": "three", "string": "s", "added_by_the_server": {"x": [1, 2]}}"#)
        XCTAssertNil(read.kind)
        XCTAssertEqual(read.string, "s")
    }

    func test_a_list_leaves_out_the_elements_that_do_not_read() throws {
        let read = try sample(#"{"list": [{"id": "1"}, {"name": "no id"}, null, 7, {"id": 2}], "nested": {"id": 3}}"#)
        XCTAssertEqual(read.list?.map(\.id), ["1", "2"])
        XCTAssertEqual(read.nested?.id, "3")
        XCTAssertEqual(try sample(#"{"list": []}"#).list?.count, 0)
    }

    // MARK: - Fixtures

    func test_the_loader_reads_the_contracts_fixtures() throws {
        for name in ["init", "tracking"] {
            XCTAssertEqual(try ContractFixtures.load(name)["contract"] as? String, ContractFixtures.version)
            let cases = try ContractFixtures.fixture(name)
            XCTAssertFalse(cases.isEmpty, name)
            XCTAssertTrue(cases.allSatisfy { $0.call != nil || $0.response != nil }, name)
        }
        let tracking = try ContractFixtures.fixture("tracking")
        let view = try XCTUnwrap(tracking.first { $0.name == "productView" })
        XCTAssertEqual(view.call?.name, "tracking.productView")
        XCTAssertEqual(view.request?.method, "POST")
        XCTAssertEqual(view.request?.path, "push")
        XCTAssertEqual(view.request?.body["event"] as? String, "view")
        XCTAssertTrue(tracking.contains { $0.expectedError?.matches(.invalidArgument("any")) == true })

        let initRefused = try XCTUnwrap(ContractFixtures.fixture("init").first { $0.response?.status == 402 })
        XCTAssertEqual(initRefused.expect["state"] as? String, "refused")
        XCTAssertNil(try ContractFixtures.fixture("init").first { $0.name.hasPrefix("нет ответа") }?.response?.status)
        XCTAssertTrue(ContractCase.ErrorSpec(type: "http", code: 404).matches(.http(code: 404, serverCode: "x")))
        XCTAssertFalse(ContractCase.ErrorSpec(type: "http", code: 404).matches(.http(code: 500, serverCode: nil)))
        XCTAssertTrue(ContractCase.ErrorSpec(type: "timeout", code: nil).matches(.timeout))
    }
}
