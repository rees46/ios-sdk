//
//  CatalogContractTests.swift
//  REES46Tests
//
//  The read methods of the profile and the catalog against the API documentation
//  (rees46.ru/help/integration): `GET /profile` (cdp/profile/get), `GET /products/counters`
//  (catalog/counters), `GET /collection/:id` (collections/api). `GET /category/:id` has no page of
//  its own there: its answer is a recorded one (`Fixtures/api_category.json`).
//

import XCTest
@testable import REES46

final class CatalogContractTests: ContractTestCase {

    // MARK: - GET /profile

    /// The answer the documentation shows for a request without `shop_secret`, as the SDK sends it.
    private let profileAnswer = """
    {"has_email": true, "computed_gender": null, "gender": null, "bought_something": false,
     "id": "profile-1", "custom_properties": {"prop_key_1": "prop_value"}}
    """

    func test_the_profile_is_read_with_the_device_and_without_the_secret() {
        onBothCores { sdk in
            answer("/profile", json: profileAnswer)

            let profile = success(outcome { sdk.getProfile(completion: $0) })

            let sent = request(sdk, "/profile")
            XCTAssertEqual(sent?.method, "GET")
            XCTAssertEqual(sent?.query["shop_id"], sdk.shopId)
            XCTAssertEqual(sent?.query["did"], "stub-did")
            XCTAssertNil(sent?.query["shop_secret"], "the SDK reads the limited profile, never with the secret")
            XCTAssertEqual(profile?.id, "profile-1")
            XCTAssertEqual(profile?.hasEmail, true)
            XCTAssertEqual(profile?.boughtSomething, false)
            XCTAssertNil(profile?.gender)
            XCTAssertEqual(profile?.customProperties["prop_key_1"] as? String, "prop_value")
        }
    }

    func test_an_error_answer_of_the_profile_fails_the_call() {
        onBothCores { sdk in
            answer("/profile", status: 400, json: #"{"status": "error", "payload": {"message": "Shop not found"}}"#)

            let result = outcome { sdk.getProfile(completion: $0) }

            guard case .failure = result else { return XCTFail("an error answer must fail: \(String(describing: result))") }
        }
    }

    // MARK: - GET /products/counters

    func test_the_counters_of_a_product_are_read_by_its_item_id() {
        onBothCores { sdk in
            answer("/products/counters", json: """
            {"daily": {"view": 12, "cart": 3, "purchase": 1},
             "now": {"view": 2, "cart": 1, "purchase": 0},
             "triggers": {"back_in_stock": 4, "price_drop": 5}}
            """)

            let counters = success(outcome { sdk.getProductCounters(item: "300275", completion: $0) })

            let sent = request(sdk, "/products/counters")
            XCTAssertEqual(sent?.method, "GET")
            XCTAssertEqual(sent?.query["shop_id"], sdk.shopId)
            XCTAssertEqual(sent?.query["item"], "300275")
            XCTAssertEqual(counters?.daily?.view, 12)
            XCTAssertEqual(counters?.daily?.cart, 3)
            XCTAssertEqual(counters?.daily?.purchase, 1)
            XCTAssertEqual(counters?.now?.view, 2)
            XCTAssertEqual(counters?.now?.cart, 1)
            XCTAssertEqual(counters?.triggers?.backInStock, 4)
            XCTAssertEqual(counters?.triggers?.priceDrop, 5)
        }
    }

    // MARK: - GET /collection/:id

    func test_a_collection_is_read_by_its_id_with_the_documented_identifiers() {
        onBothCores { sdk in
            answer("/collection/6", json: """
            {"products": [{"name": "Kettle", "url": "https://shop.test/p/1", "brand": "Tefal",
              "picture": "https://shop.test/1.jpg", "price_formatted": "1 000 ₽", "price_full_formatted": "1 000.00 ₽",
              "price": 1000, "price_full": 1000.5, "image_url": "https://shop.test/1.jpg", "currency": "₽",
              "_id": "16041", "id": "286429", "group_id": "g-1"}]}
            """)

            let collection = success(outcome {
                sdk.getCollection(
                    collectionId: "6", location: "msk", email: "buyer@example.com", phone: "+79991234567",
                    externalId: "ext-1", loyaltyId: "loyal-1", completion: $0
                )
            })

            let sent = request(sdk, "/collection/6")
            XCTAssertEqual(sent?.method, "GET")
            XCTAssertEqual(sent?.query["shop_id"], sdk.shopId)
            XCTAssertEqual(sent?.query["did"], "stub-did")
            XCTAssertEqual(sent?.query["location"], "msk")
            XCTAssertEqual(sent?.query["email"], "buyer@example.com")
            XCTAssertEqual(sent?.query["phone"], "+79991234567")
            XCTAssertEqual(sent?.query["external_id"], "ext-1")
            XCTAssertEqual(sent?.query["loyalty_id"], "loyal-1")
            let product = collection?.products.first
            XCTAssertEqual(collection?.products.count, 1)
            XCTAssertEqual(product?.id, "286429")
            XCTAssertEqual(product?.name, "Kettle")
            XCTAssertEqual(product?.brand, "Tefal")
            XCTAssertEqual(product?.price, 1000)
            XCTAssertEqual(product?.priceFull, 1000.5)
            XCTAssertEqual(product?.currency, "₽")
        }
    }

    // MARK: - GET /category/:id

    func test_a_category_is_read_by_its_slug_and_its_recorded_answer_is_taken_whole() throws {
        let recorded = ApiFixtures.json("category")
        let data = try JSONSerialization.data(withJSONObject: recorded)
        let recordedProducts = recorded["products"] as? [[String: Any]] ?? []
        XCTAssertFalse(recordedProducts.isEmpty, "the recorded answer has products")

        onBothCores { sdk in
            answer("/category/smartfony-i-gadzhety", json: String(decoding: data, as: UTF8.self))

            let category = success(outcome { sdk.getCategory(category: "smartfony-i-gadzhety", limit: 5, completion: $0) })

            let sent = request(sdk, "/category/smartfony-i-gadzhety")
            XCTAssertEqual(sent?.method, "GET")
            XCTAssertEqual(sent?.query["shop_id"], sdk.shopId)
            XCTAssertEqual(sent?.query["did"], "stub-did")
            XCTAssertEqual(category?.productsTotal, recorded["products_total"] as? Int)
            XCTAssertEqual(category?.products.count, recordedProducts.count)
            XCTAssertEqual(category?.products.first?.id, recordedProducts.first?["id"] as? String)
            XCTAssertEqual(category?.products.first?.name, recordedProducts.first?["name"] as? String)
        }
    }
}
