//
//  LoyaltyAndOrdersContractTests.swift
//  REES46Tests
//
//  The loyalty membership and the client's orders against the API documentation
//  (rees46.ru/help/integration): `POST /loyalty/members/join` and `GET /loyalty/members/status`
//  (loyalty/membership), `GET /orders/last_for_user` and `GET /orders/by_user` (cdp/client-orders).
//

import XCTest
@testable import REES46

final class LoyaltyAndOrdersContractTests: ContractTestCase {

    // MARK: - POST /loyalty/members/join

    func test_joining_the_loyalty_program_posts_the_member_and_reads_the_documented_answer() {
        onBothCores { sdk in
            answer("/loyalty/members/join", json: """
            {"status": "success", "payload": {"message": "Member is registered successfully", "identifier": "79991234567"}}
            """)

            let joined = success(outcome {
                sdk.joinLoyalty(phone: "79991234567", email: "buyer@example.com", firstName: "Ivan", lastName: "Petrov", completion: $0)
            })

            let sent = request(sdk, "/loyalty/members/join")
            XCTAssertEqual(sent?.method, "POST")
            XCTAssertEqual(sent?.body["shop_id"] as? String, sdk.shopId)
            XCTAssertEqual(sent?.body["phone"] as? String, "79991234567")
            XCTAssertEqual(sent?.body["email"] as? String, "buyer@example.com")
            XCTAssertEqual(sent?.body["first_name"] as? String, "Ivan")
            XCTAssertEqual(sent?.body["last_name"] as? String, "Petrov")
            XCTAssertNil(sent?.body["shop_secret"], "the SDK never sends the shop's secret")
            XCTAssertEqual(joined?.status, "success")
            XCTAssertEqual(joined?.payload["identifier"] as? String, "79991234567")
            XCTAssertEqual(joined?.payload["message"] as? String, "Member is registered successfully")
        }
    }

    func test_an_error_answer_of_joining_fails_the_call() {
        onBothCores { sdk in
            answer("/loyalty/members/join", status: 400, json: #"{"status": "error", "payload": {"message": "Phone is invalid"}}"#)

            let result = outcome { sdk.joinLoyalty(phone: "79991234567", email: nil, firstName: nil, lastName: nil, completion: $0) }

            guard case .failure = result else { return XCTFail("an error answer must fail: \(String(describing: result))") }
        }
    }

    // MARK: - GET /loyalty/members/status

    func test_the_member_status_is_read_by_the_identifier_with_its_level() {
        onBothCores { sdk in
            answer("/loyalty/members/status", json: """
            {"status": "success", "payload": {"member": true,
             "level": {"name": "Gold", "code": "level_gold", "expiration_date": "2028-01-01"}}}
            """)

            let status = success(outcome { sdk.getLoyaltyStatus(identifier: "79991234567", completion: $0) })

            let sent = request(sdk, "/loyalty/members/status")
            XCTAssertEqual(sent?.method, "GET")
            XCTAssertEqual(sent?.query["shop_id"], sdk.shopId)
            XCTAssertEqual(sent?.query["identifier"], "79991234567")
            XCTAssertNil(sent?.query["shop_secret"])
            XCTAssertEqual(status?.status, "success")
            XCTAssertEqual(status?.member, true)
            XCTAssertEqual(status?.level?.name, "Gold")
            XCTAssertEqual(status?.level?.code, "level_gold")
            XCTAssertEqual(status?.level?.expirationDate, "2028-01-01")
        }
    }

    func test_a_client_outside_the_program_has_no_level() {
        onBothCores { sdk in
            answer("/loyalty/members/status", json: """
            {"status": "success", "payload": {"member": false, "level": {"name": null, "code": null, "expiration_date": null}}}
            """)

            let status = success(outcome { sdk.getLoyaltyStatus(identifier: "79990000000", completion: $0) })

            XCTAssertEqual(status?.member, false)
            XCTAssertNil(status?.level?.name)
            XCTAssertNil(status?.level?.code)
            XCTAssertNil(status?.level?.expirationDate)
        }
    }

    // MARK: - GET /orders/last_for_user

    func test_the_last_order_is_read_for_the_device_as_a_list_of_products() {
        onBothCores { sdk in
            answer("/orders/last_for_user", json: """
            [{"name": "Kettle", "price_formatted": "1000 ₽", "price": 1000, "price_full": 1000.0,
              "url": "https://shop.test/product/123", "image_url": "https://shop.test/pictures/123.png",
              "currency": "₽", "id": "123", "brand": "Tefal"}]
            """)

            let last = success(outcome { sdk.getLastOrderProducts(completion: $0) })

            let sent = request(sdk, "/orders/last_for_user")
            XCTAssertEqual(sent?.method, "GET")
            XCTAssertEqual(sent?.query["shop_id"], sdk.shopId)
            XCTAssertEqual(sent?.query["did"], "stub-did")
            XCTAssertEqual(sent?.query["sid"], sdk.getSession(), "the session the SDK keeps for the device")
            XCTAssertEqual(last?.products.count, 1)
            XCTAssertEqual(last?.products.first?.id, "123")
            XCTAssertEqual(last?.products.first?.name, "Kettle")
            XCTAssertEqual(last?.products.first?.price, 1000)
            XCTAssertEqual(last?.products.first?.currency, "₽")
        }
    }

    // MARK: - GET /orders/by_user

    func test_the_orders_of_a_client_are_read_with_the_secret_the_app_passes_and_its_identifiers() {
        onBothCores { sdk in
            answer("/orders/by_user", json: """
            {"status": "success", "data": {"orders": [{"id": "order-1", "date": "2026-10-01 12:00",
              "tax_free": false, "items": [{"price": "1000", "status": "delivered", "item": {"id": "123", "name": "Kettle"}}]}]}}
            """)

            let orders = success(outcome {
                sdk.getUserOrders(
                    shopSecret: "secret-key", did: nil, email: "buyer@example.com", phone: nil, loyaltyId: nil,
                    externalId: nil, dateFrom: "2026-10-01", completion: $0
                )
            })

            let sent = request(sdk, "/orders/by_user")
            XCTAssertEqual(sent?.method, "GET")
            XCTAssertEqual(sent?.query["shop_id"], sdk.shopId)
            XCTAssertEqual(sent?.query["shop_secret"], "secret-key")
            XCTAssertEqual(sent?.query["email"], "buyer@example.com")
            XCTAssertEqual(sent?.query["date_from"], "2026-10-01")
            XCTAssertEqual(orders?.count, 1)
            XCTAssertEqual(orders?.first?.id, "order-1")
            XCTAssertEqual(orders?.first?.date, "2026-10-01 12:00")
            XCTAssertEqual(orders?.first?.taxFree, false)
            XCTAssertEqual(orders?.first?.items.first?.price, "1000")
            XCTAssertEqual(orders?.first?.items.first?.status, "delivered")
            XCTAssertEqual(orders?.first?.items.first?.item?.name, "Kettle")
        }
    }

    func test_the_orders_of_the_device_itself_go_with_its_did() {
        onBothCores { sdk in
            answer("/orders/by_user", json: #"{"status": "success", "data": {"orders": []}}"#)

            let orders = success(outcome {
                sdk.getUserOrders(
                    shopSecret: "secret-key", did: nil, email: nil, phone: nil, loyaltyId: nil, externalId: nil,
                    dateFrom: nil, completion: $0
                )
            })

            XCTAssertEqual(request(sdk, "/orders/by_user")?.query["did"], "stub-did", "one identifier is required: the device's")
            XCTAssertEqual(orders?.count, 0)
        }
    }
}
