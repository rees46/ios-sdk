//
//  PredictContractTests.swift
//  REES46Tests
//
//  The root method `getProbabilityToPurchase(params:completion:)` on either core, against the contract
//  (`sdk/contract/predict.md`): `GET /api/v3/cdp/users/probability-to-purchase` on the shop's
//  `appDomain` with the device id and no contact, the answer's `payload` read into the old model, the
//  old errors.
//

import XCTest
@testable import REES46

final class PredictContractTests: ContractTestCase {

    private static let path = "/api/v3/cdp/users/probability-to-purchase"
    private static let appDomain = "app.cluster.test"

    func test_the_forecast_is_asked_on_the_app_host_for_the_device_and_read_from_the_payload() {
        onBothCores(appDomain: Self.appDomain) { sdk in
            answer(Self.path, json: #"{"status": "success", "payload": {"probability": 0.42, "client_id": 12345}}"#)

            let params = PurchasePredictParams(email: "buyer@example.com", phone: "+79990000000", telegramId: "777", loyaltyId: "L-1")
            let forecast = success(outcome { sdk.getProbabilityToPurchase(params: params, completion: $0) })

            let sent = request(sdk, Self.path)
            XCTAssertEqual(sent?.method, "GET")
            XCTAssertEqual(sent?.url?.host, Self.appDomain, "the host of API v3, the shop's appDomain")
            XCTAssertEqual(sent?.query["shop_id"], sdk.shopId)
            XCTAssertEqual(sent?.query["did"], "stub-did")
            XCTAssertEqual(sent?.query["sid"], sdk.getSession())
            XCTAssertEqual(sent?.query["stream"], "ios")
            XCTAssertEqual(sent?.query["segment"], sdk.segment)
            for contact in ["email", "phone", "telegram_id", "loyalty_id", "external_id", "shop_secret"] {
                XCTAssertNil(sent?.query[contact], "the customer is the device id: no \(contact)")
            }
            XCTAssertTrue(StubURLProtocol.requests(to: "/predict/probability-to-purchase", shop: sdk.shopId).isEmpty, "not the API host's path")
            XCTAssertEqual(forecast?.probability, 0.42)
            XCTAssertEqual(forecast?.clientId, "12345", "the client's number as a string")
        }
    }

    func test_a_customer_the_server_does_not_know_is_a_success_with_an_empty_client() {
        onBothCores { sdk in
            answer(Self.path, json: #"{"status": "success", "payload": {"probability": 0, "client_id": null}}"#)

            let forecast = success(outcome { sdk.getProbabilityToPurchase(params: PurchasePredictParams(), completion: $0) })

            XCTAssertEqual(sent(sdk)?.url?.host, Rees46Config.defaultAppDomain)
            XCTAssertEqual(forecast?.probability, 0)
            XCTAssertEqual(forecast?.clientId, "")
        }
    }

    func test_a_customer_without_events_has_a_zero_probability_and_the_client() {
        onBothCores { sdk in
            answer(Self.path, json: #"{"status": "success", "payload": {"probability": "0.0", "client_id": "98765"}}"#)

            let forecast = success(outcome { sdk.getProbabilityToPurchase(params: PurchasePredictParams(), completion: $0) })

            XCTAssertEqual(forecast?.probability, 0)
            XCTAssertEqual(forecast?.clientId, "98765")
        }
    }

    func test_an_error_answer_of_the_server_fails_as_an_invalid_response() {
        let refusals = [
            (400, "Shop ID and user identifier are required"),
            (402, "Shop does not have access to cdp"),
            (403, "Shop is not active"),
            (404, "Shop not found"),
        ]
        onBothCores { sdk in
            for (status, message) in refusals {
                answer(Self.path, status: status, json: #"{"status": "fail", "message": "\#(message)"}"#)

                let result = outcome { sdk.getProbabilityToPurchase(params: PurchasePredictParams(), completion: $0) }

                guard case .failure(.invalidResponse)? = result else {
                    XCTFail("\(status): \(String(describing: result))")
                    continue
                }
            }
        }
    }

    func test_an_answer_without_a_numeric_probability_in_its_payload_is_a_decode_error() {
        let answers = [
            #"{"status": "success", "payload": {"probability": null, "client_id": 1}}"#,
            #"{"status": "success", "payload": {"client_id": 1}}"#,
            #"{"status": "success", "payload": {"probability": "high", "client_id": 1}}"#,
            #"{"status": "success"}"#,
            // The old path's answer, without the payload.
            #"{"probability": 0.42, "client_id": 12345}"#,
        ]
        onBothCores { sdk in
            for json in answers {
                answer(Self.path, json: json)

                let result = outcome { sdk.getProbabilityToPurchase(params: PurchasePredictParams(), completion: $0) }

                guard case .failure(.decodeError)? = result else {
                    XCTFail("\(json): \(String(describing: result))")
                    continue
                }
            }
        }
    }

    /// The last request of `sdk`'s shop for the forecast.
    private func sent(_ sdk: SimplePersonalizationSDK) -> StubRequest? {
        request(sdk, Self.path)
    }
}
