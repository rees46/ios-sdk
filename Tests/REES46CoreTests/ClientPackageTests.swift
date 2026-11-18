//
//  ClientPackageTests.swift
//  REES46CoreTests
//
//  The client's namespaces without a server — `profile`, `subscriptions`, `segments` —: the request of
//  each call of the proposed fixtures, the calls refused before anything is sent, and what the request
//  path makes of each answer.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class ClientPackageTests: XCTestCase {

    private typealias Fixtures = NamespaceFixtures

    // MARK: - The fixtures

    func test_profile_builds_the_fixtures_requests_and_refuses_its_arguments() throws {
        try Fixtures.checkRequests("profile", build: Self.profile)
    }

    func test_profile_ends_as_the_fixture_says_for_each_answer() throws {
        try Fixtures.checkAnswers("profile", build: Self.profile)
    }

    func test_subscriptions_build_the_fixtures_requests_and_refuse_its_arguments() throws {
        try Fixtures.checkRequests("subscriptions", build: Self.subscriptions)
    }

    func test_subscriptions_end_as_the_fixture_says_for_each_answer() throws {
        try Fixtures.checkAnswers("subscriptions", build: Self.subscriptions)
    }

    func test_segments_build_the_fixtures_requests_and_refuse_its_arguments() throws {
        try Fixtures.checkRequests("segments", build: Self.segments)
    }

    func test_segments_end_as_the_fixture_says_for_each_answer() throws {
        try Fixtures.checkAnswers("segments", build: Self.segments)
    }

    func test_the_clients_fixtures_are_proposed_until_the_contract_has_them() throws {
        for name in ["profile", "subscriptions", "segments"] {
            XCTAssertEqual(try ContractFixtures.load(name, from: .proposed)["contract"] as? String, ContractFixtures.version, name)
            XCTAssertTrue(try ContractFixtures.fixture(name, from: .proposed).allSatisfy { $0.call?.namespace == name }, name)
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: ContractFixtures.url(name).path),
                "the contract has \(name).json now: copy it into contract-\(ContractFixtures.version) and remove the proposed one"
            )
        }
    }

    // MARK: - Calls of the fixtures

    private static func profile(_ call: ContractCase.Call) throws -> ErasedRequest {
        switch call.method {
        case "get":
            return ErasedRequest(ProfileAPIImpl.profileRequest, call: call.name)
        case "set":
            return ErasedRequest(try ProfileAPIImpl.setRequest(profileRequest(call.args["request"])), call: call.name)
        case "getLastOrder":
            return ErasedRequest(ProfileAPIImpl.lastOrderRequest, call: call.name)
        default:
            throw Unknown(call: call.name)
        }
    }

    private static func subscriptions(_ call: ContractCase.Call) throws -> ErasedRequest {
        let args = call.args
        let email = Fixtures.string(args["email"])
        let phone = Fixtures.string(args["phone"])
        switch call.method {
        case "manage":
            return ErasedRequest(try SubscriptionsAPIImpl.manageRequest(updateRequest(args["request"])), call: call.name)
        case "check":
            return ErasedRequest(SubscriptionsAPIImpl.checkRequest, call: call.name)
        case "subscribeForPriceDrop":
            return ErasedRequest(try SubscriptionsAPIImpl.priceDropRequest(
                itemId: Fixtures.string(args["itemId"]) ?? "",
                currentPrice: Fixtures.double(args["currentPrice"]) ?? 0,
                email: email,
                phone: phone
            ), call: call.name)
        case "unsubscribeFromPriceDrop":
            return ErasedRequest(try SubscriptionsAPIImpl.unsubscribeRequest(
                "subscriptions/unsubscribe_from_product_price",
                itemIds: Fixtures.strings(args["itemIds"]) ?? [],
                email: email,
                phone: phone
            ), call: call.name)
        case "subscribeForBackInStock":
            let properties = (args["properties"] as? [String: Any]).map {
                Rees46.BackInStockProperties(
                    fashionSize: Fixtures.string($0["fashionSize"]),
                    fashionColor: Fixtures.string($0["fashionColor"]),
                    barcode: Fixtures.string($0["barcode"])
                )
            }
            return ErasedRequest(try SubscriptionsAPIImpl.backInStockRequest(
                itemId: Fixtures.string(args["itemId"]) ?? "",
                properties: properties,
                email: email,
                phone: phone
            ), call: call.name)
        case "unsubscribeFromBackInStock":
            return ErasedRequest(try SubscriptionsAPIImpl.unsubscribeRequest(
                "subscriptions/unsubscribe_from_product_available",
                itemIds: Fixtures.strings(args["itemIds"]) ?? [],
                email: email,
                phone: phone
            ), call: call.name)
        default:
            throw Unknown(call: call.name)
        }
    }

    private static func segments(_ call: ContractCase.Call) throws -> ErasedRequest {
        let args = call.args
        switch call.method {
        case "add", "remove":
            return ErasedRequest(try SegmentsAPIImpl.changeRequest(
                "segments/\(call.method)",
                segmentId: Fixtures.int(args["segmentId"]) ?? 0,
                email: Fixtures.string(args["email"]),
                phone: Fixtures.string(args["phone"])
            ), call: call.name)
        case "get":
            return ErasedRequest(SegmentsAPIImpl.listRequest, call: call.name)
        default:
            throw Unknown(call: call.name)
        }
    }

    private static func gender(_ value: Any?) -> Gender? {
        (value as? String).flatMap(Gender.init(rawValue:))
    }

    private static func profileRequest(_ value: Any?) -> Rees46.ProfileUpdateRequest {
        let json = value as? [String: Any] ?? [:]
        return Rees46.ProfileUpdateRequest(
            email: Fixtures.string(json["email"]),
            phone: Fixtures.string(json["phone"]),
            externalId: Fixtures.string(json["externalId"]),
            loyaltyId: Fixtures.string(json["loyaltyId"]),
            telegramId: Fixtures.string(json["telegramId"]),
            fbId: Fixtures.string(json["fbId"]),
            vkId: Fixtures.string(json["vkId"]),
            firstName: Fixtures.string(json["firstName"]),
            lastName: Fixtures.string(json["lastName"]),
            gender: gender(json["gender"]),
            birthday: Fixtures.string(json["birthday"]),
            age: Fixtures.int(json["age"]),
            location: Fixtures.string(json["location"]),
            kids: (json["kids"] as? [[String: Any]])?.map {
                Rees46.ProfileKid(gender: gender($0["gender"]), birthday: Fixtures.string($0["birthday"]))
            },
            cars: (json["cars"] as? [[String: Any]])?.map {
                Rees46.ProfileCar(brand: Fixtures.string($0["brand"]), model: Fixtures.string($0["model"]), vds: Fixtures.string($0["vds"]))
            },
            customProperties: json["customProperties"] as? [String: Any]
        )
    }

    private static func updateRequest(_ value: Any?) -> Rees46.SubscriptionsUpdateRequest {
        let json = value as? [String: Any] ?? [:]
        var request = Rees46.SubscriptionsUpdateRequest(
            email: Fixtures.string(json["email"]),
            phone: Fixtures.string(json["phone"]),
            externalId: Fixtures.string(json["externalId"]),
            loyaltyId: Fixtures.string(json["loyaltyId"]),
            telegramId: Fixtures.string(json["telegramId"])
        )
        let flags: [String: WritableKeyPath<Rees46.SubscriptionsUpdateRequest, Bool?>] = [
            "emailBulk": \.emailBulk, "emailChain": \.emailChain, "emailTransactional": \.emailTransactional,
            "smsBulk": \.smsBulk, "smsChain": \.smsChain, "smsTransactional": \.smsTransactional,
            "webPushBulk": \.webPushBulk, "webPushChain": \.webPushChain, "webPushTransactional": \.webPushTransactional,
            "mobilePushBulk": \.mobilePushBulk, "mobilePushChain": \.mobilePushChain, "mobilePushTransactional": \.mobilePushTransactional,
            "telegramBulk": \.telegramBulk, "telegramChain": \.telegramChain, "telegramTransactional": \.telegramTransactional,
            "whatsappBulk": \.whatsappBulk, "whatsappChain": \.whatsappChain, "whatsappTransactional": \.whatsappTransactional,
            "maxBulk": \.maxBulk, "maxChain": \.maxChain, "maxTransactional": \.maxTransactional,
            "walletBulk": \.walletBulk, "walletChain": \.walletChain, "walletTransactional": \.walletTransactional
        ]
        for (name, path) in flags {
            request[keyPath: path] = Fixtures.bool(json[name])
        }
        return request
    }

    private struct Unknown: Error {
        let call: String
    }

    // MARK: - Beyond the fixtures

    func test_a_2xx_without_a_body_is_the_empty_value() throws {
        func answer<Value>(_ request: ApiRequest<Value>) -> Result<Value, Rees46.SdkError> {
            let empty = NetworkClient.Response(status: 204, body: Data(), retryAfter: nil, result: NetworkClient.classify(status: 204, body: Data()))
            return NamespaceRequests.value(of: empty, for: request, call: "test", logger: SdkLogger(shopId: "package", level: .none))
        }
        XCTAssertNil(try answer(ProfileAPIImpl.profileRequest).get().id)
        XCTAssertEqual(try answer(ProfileAPIImpl.lastOrderRequest).get(), [])
        XCTAssertFalse(try answer(SubscriptionsAPIImpl.checkRequest).get().exists)
        XCTAssertEqual(try answer(SegmentsAPIImpl.listRequest).get(), [])
        XCTAssertNoThrow(try answer(SegmentsAPIImpl.changeRequest("segments/add", segmentId: 1, email: nil, phone: nil)).get())
    }

    func test_custom_properties_must_be_json_values() {
        func set(_ properties: [String: Any]) throws -> [String: Any] {
            try ProfileAPIImpl.setRequest(Rees46.ProfileUpdateRequest(customProperties: properties)).body
        }
        XCTAssertThrowsError(try set(["date": Date()]))
        XCTAssertThrowsError(try set(["list": [1, Date()]]))
        XCTAssertThrowsError(try set(["nan": Double.nan]))
        XCTAssertThrowsError(try set(["": "x"]))
        XCTAssertThrowsError(try set(["seance": "x"]))
        XCTAssertThrowsError(try set(["auto": "x"]))
        let nothing: String? = nil
        let body = try? set(["none": nothing as Any, "some": Optional("x") as Any, "nested": ["a": nothing as Any]])
        XCTAssertTrue(body?["none"] is NSNull, "nil is JSON null")
        XCTAssertEqual(body?["some"] as? String, "x")
        XCTAssertTrue((body?["nested"] as? [String: Any])?["a"] is NSNull)
        // What the client writes.
        XCTAssertNotNil(SafeJSON.data(body ?? [:]))
    }

    func test_a_birthday_is_an_existing_day_of_the_years_1000_to_2999() {
        XCTAssertNoThrow(try ClientBody.birthday("2000-02-29", "birthday"))
        XCTAssertNoThrow(try ClientBody.birthday("1000-01-01", "birthday"))
        XCTAssertNoThrow(try ClientBody.birthday("2999-12-31", "birthday"))
        XCTAssertThrowsError(try ClientBody.birthday("2001-02-29", "birthday"))
        XCTAssertThrowsError(try ClientBody.birthday("1900-02-29", "birthday"))
        XCTAssertThrowsError(try ClientBody.birthday("2001-04-31", "birthday"))
        XCTAssertThrowsError(try ClientBody.birthday("2001-13-01", "birthday"))
        XCTAssertThrowsError(try ClientBody.birthday("2001-2-01", "birthday"))
        XCTAssertThrowsError(try ClientBody.birthday("+201-02-01", "birthday"))
        XCTAssertThrowsError(try ClientBody.birthday("２００１-02-01", "birthday"), "digits of another script")
        XCTAssertThrowsError(try ClientBody.birthday("0999-12-31", "birthday"), "the server takes the years 1000 to 2999")
        XCTAssertThrowsError(try ClientBody.birthday("3000-01-01", "birthday"))
        XCTAssertThrowsError(try ClientBody.birthday("", "birthday"))
    }

    func test_the_comparison_with_a_fixture_finds_what_differs() {
        XCTAssertFalse(ContractJSON.mismatches(["a": 1, "b": "x"], ["a": 2], at: "result").isEmpty)
        XCTAssertFalse(ContractJSON.mismatches(["a": NSNull()], ["a": "x"], at: "result").isEmpty)
        XCTAssertFalse(ContractJSON.mismatches(["a": "x"], ["a": NSNull()], at: "result").isEmpty)
        XCTAssertFalse(ContractJSON.mismatches(["a": [1, 2]], ["a": [1]], at: "result").isEmpty)
        XCTAssertFalse(ContractJSON.mismatches([String: Any](), ["a": 1], at: "result").isEmpty)
        XCTAssertFalse(ContractJSON.mismatches(["k": "v"], [String: Any](), at: "result").isEmpty, "{} has no field")
        XCTAssertFalse(ContractJSON.mismatches(["a": 1, "b": 2], ["a": 1], at: "result").isEmpty, "a field more")
        XCTAssertTrue(ContractJSON.mismatches(["b": NSNull()], ["a": NSNull()], at: "result").isEmpty, "a field without a value is none")
        XCTAssertTrue(ContractJSON.mismatches(["a": 19990], ["a": 19990.0], at: "result").isEmpty)
        let segment = ContractJSON.of(Rees46.Segment(id: 313, type: nil)) as? [String: Any]
        XCTAssertEqual(segment?["id"] as? Double, 313)
        XCTAssertTrue(segment?["type"] is NSNull)
        XCTAssertTrue(ContractJSON.of(()) is NSNull)
        XCTAssertEqual(ContractJSON.of(Gender.female) as? String, "female")
    }

    func test_the_gender_goes_as_its_letter_and_reads_from_it() {
        XCTAssertEqual(Gender.male.wire, "m")
        XCTAssertEqual(Gender.female.wire, "f")
        XCTAssertEqual(Gender(wire: "F"), .female)
        XCTAssertNil(Gender(wire: "x"))
    }
}
