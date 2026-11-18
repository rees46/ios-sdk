//
//  LoyaltyPackageTests.swift
//  REES46CoreTests
//
//  `loyalty.join`, `getStatus` and `getPromotions` without a server: the requests they build, the
//  arguments they refuse, and what they make of each answer of the proposed fixture.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class LoyaltyPackageTests: XCTestCase {

    func test_the_requests_of_the_loyalty_fixture_and_its_refusals() throws {
        let cases = try FixtureCase.load("loyalty").filter { $0.item.response == nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let make = { try Self.request(for: item) }
            if item.item.request != nil {
                FixtureMatching.assert(try make(), is: item)
            } else {
                FixtureMatching.assertRefused(item, make)
            }
        }
    }

    func test_the_answers_of_the_loyalty_fixture_end_as_it_says() throws {
        let cases = try FixtureCase.load("loyalty").filter { $0.item.response?.status != nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            switch item.method {
            case "join":
                let request = try LoyaltyAPIImpl.joinRequest(phone: "+7", firstName: nil, lastName: nil, gender: nil, birthday: nil)
                FixtureMatching.assert(try FixtureMatching.outcome(of: item, for: request, call: "loyalty.join"), as: item) {
                    ["identifier": $0.identifier] as [String: Any]
                }
            case "getStatus":
                let request = try LoyaltyAPIImpl.statusRequest(phone: "+7")
                FixtureMatching.assert(try FixtureMatching.outcome(of: item, for: request, call: "loyalty.getStatus"), as: item, json: Self.json(status:))
            case "getPromotions":
                let request = try LoyaltyAPIImpl.promotionsRequest(locationId: nil, promoCodes: nil, chargeBonuses: nil, currentTime: nil)
                FixtureMatching.assert(try FixtureMatching.outcome(of: item, for: request, call: "loyalty.getPromotions"), as: item) {
                    $0.map(Self.json(promotion:))
                }
            default:
                XCTFail("\(item.name): a method the test does not know")
            }
        }
    }

    // MARK: - Arguments

    func test_a_birthday_is_an_existing_day_of_the_calendar_as_yyyy_mm_dd() {
        for date in ["1990-05-17", "2024-02-29", "2000-12-31", "0999-12-31", "3000-01-01"] {
            XCTAssertTrue(ApiArguments.isCalendarDate(date), date)
        }
        for date in ["2023-02-29", "1900-02-29", "1990-02-30", "1990-13-01", "1990-00-10", "1990-05-00", "1990-5-17",
                     "17.05.1990", "1990-05-17T00:00:00Z", " 1990-05-17", "", "１９９０-05-17"] {
            XCTAssertFalse(ApiArguments.isCalendarDate(date), date)
        }
    }

    func test_the_current_time_is_hh_mm_of_a_day() {
        for time in ["00:00", "09:30", "23:59"] {
            XCTAssertTrue(LoyaltyAPIImpl.isTime(time), time)
        }
        for time in ["24:00", "9:30", "18:60", "18-30", "18:30:00", ""] {
            XCTAssertFalse(LoyaltyAPIImpl.isTime(time), time)
        }
    }

    func test_what_is_not_given_is_not_sent() throws {
        let join = try LoyaltyAPIImpl.joinRequest(phone: "+79991234567", firstName: " ", lastName: "", gender: nil, birthday: nil)
        XCTAssertEqual(Set(join.body.keys), ["phone"], "a blank name is none, and no email: the server reads it only with the secret")
        XCTAssertEqual(join.method, .post)

        let promotions = try LoyaltyAPIImpl.promotionsRequest(locationId: "", promoCodes: [], chargeBonuses: false, currentTime: nil)
        XCTAssertEqual(promotions.query, ["charge_bonuses": "false"])
        XCTAssertTrue(promotions.queryLists.isEmpty, "an empty list is not sent")
        XCTAssertThrowsError(try LoyaltyAPIImpl.promotionsRequest(locationId: nil, promoCodes: [" "], chargeBonuses: nil, currentTime: nil))
        XCTAssertThrowsError(try LoyaltyAPIImpl.statusRequest(phone: " "))
        XCTAssertThrowsError(try LoyaltyAPIImpl.joinRequest(phone: "+7", firstName: nil, lastName: nil, gender: nil, birthday: ""))
    }

    // MARK: - Answers

    func test_a_promotion_without_an_id_is_left_out_and_an_answer_without_promotions_is_not_one() throws {
        let request = try LoyaltyAPIImpl.promotionsRequest(locationId: nil, promoCodes: nil, chargeBonuses: nil, currentTime: nil)
        let read = try request.decode(Data(#"{"payload":{"promotions":[{"name":"no id"},{"id":"x"},{"id":3}]}}"#.utf8))
        XCTAssertEqual(read.map(\.id), [3])
        XCTAssertEqual(read.first?.name, "", "a name it does not have is empty")
        XCTAssertEqual(try request.decode(Data()).count, 0, "an answer without a body is no promotion")
        XCTAssertThrowsError(try request.decode(Data(#"{"status":"success"}"#.utf8)))
        XCTAssertThrowsError(try request.decode(Data(#"{"payload":{"promotions":{}}}"#.utf8)))
    }

    func test_a_status_needs_payload_member_and_a_level_needs_its_code() throws {
        let request = try LoyaltyAPIImpl.statusRequest(phone: "+7")
        XCTAssertThrowsError(try request.decode(Data(#"{"status":"success","payload":{"level":null}}"#.utf8)))
        XCTAssertThrowsError(try request.decode(Data()))
        let member = try request.decode(Data(#"{"payload":{"member":"true","level":{"code":"gold"}}}"#.utf8))
        XCTAssertTrue(member.isMember)
        XCTAssertEqual(member.level?.code, "gold")
        XCTAssertNil(member.level?.name)
        XCTAssertNil(member.level?.expirationDate)
        XCTAssertNil(try request.decode(Data(#"{"payload":{"member":true}}"#.utf8)).level)
        XCTAssertNil(try request.decode(Data(#"{"payload":{"member":true,"level":{"code":""}}}"#.utf8)).level)
    }

    func test_the_loyalty_fixture_is_proposed_until_the_contract_has_one() {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: ContractFixtures.url("loyalty").path),
            "the contract has loyalty.json now: copy it into contract-\(ContractFixtures.version) and remove the proposed one"
        )
    }

    // MARK: - Helpers

    /// The request of the case's call, built from its arguments.
    private static func request(for item: FixtureCase) throws -> CoreRequest {
        let args = item.args
        switch item.method {
        case "join":
            let gender = (args["gender"] as? String).map { $0 == "male" ? Gender.male : Gender.female }
            return try LoyaltyAPIImpl.joinRequest(
                phone: args["phone"] as? String ?? "", firstName: args["firstName"] as? String,
                lastName: args["lastName"] as? String, gender: gender, birthday: args["birthday"] as? String
            ).coreRequest
        case "getStatus":
            return try LoyaltyAPIImpl.statusRequest(phone: args["phone"] as? String ?? "").coreRequest
        case "getPromotions":
            return try LoyaltyAPIImpl.promotionsRequest(
                locationId: args["locationId"] as? String, promoCodes: args["promoCodes"] as? [String],
                chargeBonuses: args["chargeBonuses"] as? Bool, currentTime: args["currentTime"] as? String
            ).coreRequest
        default:
            throw Rees46.SdkError.invalidArgument("a method the test does not know: \(item.method)")
        }
    }

    static func json(status: LoyaltyStatus) -> [String: Any] {
        [
            "isMember": status.isMember,
            "level": FixtureMatching.field(status.level.map { level -> [String: Any] in
                [
                    "code": FixtureMatching.field(level.code), "name": FixtureMatching.field(level.name),
                    "expirationDate": FixtureMatching.field(level.expirationDate),
                ]
            }),
        ]
    }

    static func json(promotion: LoyaltyPromotion) -> [String: Any] {
        let rewardType: String?
        switch promotion.rewardType {
        case .discount?: rewardType = "discount"
        case .bonusesEarn?: rewardType = "bonusesEarn"
        case .bonusesUsage?: rewardType = "bonusesUsage"
        case nil: rewardType = nil
        }
        return [
            "id": promotion.id, "name": promotion.name, "description": FixtureMatching.field(promotion.description),
            "startDate": FixtureMatching.field(promotion.startDate), "finishDate": FixtureMatching.field(promotion.finishDate),
            "stream": FixtureMatching.field(promotion.stream), "badgeLabel": FixtureMatching.field(promotion.badgeLabel),
            "badgeColor": FixtureMatching.field(promotion.badgeColor), "rewardType": FixtureMatching.field(rewardType),
        ]
    }
}
