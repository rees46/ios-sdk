//
//  PredictPackageTests.swift
//  REES46CoreTests
//
//  `predict.getProbabilityToPurchase` without a server: the request it builds, and what it makes of each
//  answer of the proposed fixture.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class PredictPackageTests: XCTestCase {

    func test_the_request_of_the_predict_fixture_goes_to_api_v3_with_no_contact_and_the_general_timeout() throws {
        let cases = try FixtureCase.load("predict").filter { $0.item.request != nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            FixtureMatching.assert(PredictAPIImpl.probabilityRequest.coreRequest, is: item)
        }
        let request = PredictAPIImpl.probabilityRequest
        XCTAssertTrue(request.query.isEmpty, "the device id is the customer: no email, phone or other contact")
        XCTAssertNil(request.timeout, "the general read timeout, not 15 seconds of its own")
        XCTAssertEqual(request.host, .app, "the host of API v3: the API host's old path answers 503")
    }

    func test_the_answers_of_the_predict_fixture_end_as_it_says() throws {
        let cases = try FixtureCase.load("predict").filter { $0.item.response?.status != nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let result = try FixtureMatching.outcome(of: item, for: PredictAPIImpl.probabilityRequest, call: "predict.getProbabilityToPurchase")
            FixtureMatching.assert(result, as: item) { value in
                ["probability": value.probability, "clientId": FixtureMatching.field(value.clientId)] as [String: Any]
            }
        }
    }

    func test_numbers_may_come_as_strings_and_an_answer_without_a_payload_is_no_forecast() throws {
        let request = PredictAPIImpl.probabilityRequest
        let read = try request.decode(Data(#"{"status": "success", "payload": {"probability": "0.73", "client_id": 12345678901}}"#.utf8))
        XCTAssertEqual(read.probability, 0.73, accuracy: 1e-9)
        XCTAssertEqual(read.clientId, "12345678901", "a number is its digits")
        XCTAssertNil(try request.decode(Data(#"{"payload": {"probability": 0.1}}"#.utf8)).clientId, "no client_id: no customer")
        XCTAssertNil(try request.decode(Data(#"{"payload": {"probability": 0.1, "client_id": ""}}"#.utf8)).clientId)
        XCTAssertThrowsError(try request.decode(Data()))
        XCTAssertThrowsError(try request.decode(Data(#"{"payload": {"probability": null}}"#.utf8)))
        XCTAssertThrowsError(try request.decode(Data(#"{"probability": 0.42, "client_id": 1}"#.utf8)), "the old path's answer")
    }

    func test_the_predict_fixture_is_proposed_until_the_contract_has_one() {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: ContractFixtures.url("predict").path),
            "the contract has predict.json now: copy it into contract-\(ContractFixtures.version) and remove the proposed one"
        )
    }
}
