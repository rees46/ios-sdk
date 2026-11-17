//
//  SlidersPackageTests.swift
//  REES46CoreTests
//
//  `sliders.get` and the banner events of `tracking` without a server: the requests and the events they
//  build, the arguments they refuse, and what `sliders.get` makes of each answer of the proposed fixture.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class SlidersPackageTests: XCTestCase {

    func test_the_requests_of_the_sliders_fixture_and_its_refusals() throws {
        let cases = try FixtureCase.load("sliders").filter { $0.item.response == nil && $0.item.call?.namespace == "sliders" }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let make = {
                try SlidersAPIImpl.getRequest(
                    code: item.args["code"] as? String ?? "", tags: item.args["tags"] as? [String], locationId: item.args["locationId"] as? String
                )
            }
            if item.item.request != nil {
                FixtureMatching.assert(try make().coreRequest, is: item)
            } else {
                FixtureMatching.assertRefused(item, make)
            }
        }
    }

    func test_the_answers_of_the_sliders_fixture_end_as_it_says() throws {
        let cases = try FixtureCase.load("sliders").filter { $0.item.response?.status != nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let request = try SlidersAPIImpl.getRequest(code: item.args["code"] as? String ?? "", tags: nil, locationId: nil)
            FixtureMatching.assert(try FixtureMatching.outcome(of: item, for: request, call: "sliders.get"), as: item, json: Self.json(slider:))
        }
    }

    func test_the_banner_events_of_the_fixture_and_their_refusals() throws {
        let cases = try FixtureCase.load("sliders").filter { $0.item.call?.namespace == "tracking" }
        XCTAssertEqual(Set(cases.map(\.method)), ["bannerView", "bannerClick"])
        for item in cases {
            let event = try XCTUnwrap(BannerEvent(rawValue: item.method == "bannerView" ? "view" : "click"))
            let make = { try event.body(bannerId: item.args["bannerId"] as? String ?? "", code: item.args["code"] as? String ?? "") }
            if item.item.request != nil {
                FixtureMatching.assert(CoreRequest(method: .post, path: BannerEvent.path, body: try make()), is: item)
            } else {
                FixtureMatching.assertRefused(item, make)
            }
        }
    }

    func test_a_banner_event_sends_a_whole_number_and_no_recommended_by() throws {
        let body = try BannerEvent.view.body(bannerId: "12", code: "homepage_mobile")
        XCTAssertEqual(body["banner_id"] as? Int, 12)
        XCTAssertNil(body["recommended_by"], "the address does not read it")
        XCTAssertEqual(Set(body.keys), ["event", "banner_id", "recommended_code"], "the queue adds the shop, the device and the session")
        XCTAssertEqual(try BannerEvent.view.body(bannerId: "4294967295", code: "c")["banner_id"] as? Int, 4_294_967_295)
        for id in ["0", "-3", "+12", " 12", "12.5", "1e3", " ", "4294967296", "١٢"] {
            XCTAssertThrowsError(try BannerEvent.click.body(bannerId: id, code: "c"), id)
        }
        XCTAssertThrowsError(try BannerEvent.click.body(bannerId: "12", code: "  "))
    }

    func test_tags_are_refused_when_blank_and_lists_left_empty_are_not_sent() throws {
        XCTAssertThrowsError(try SlidersAPIImpl.getRequest(code: "c", tags: [" "], locationId: nil))
        XCTAssertThrowsError(try SlidersAPIImpl.getRequest(code: " ", tags: nil, locationId: nil))
        let request = try SlidersAPIImpl.getRequest(code: "c", tags: [], locationId: " ")
        XCTAssertEqual(request.query, ["code": "c"], "no contacts, no empty tags or location")
    }

    func test_a_banner_needs_its_id_and_takes_the_sliders_code_when_it_has_none() throws {
        let request = try SlidersAPIImpl.getRequest(code: "main", tags: nil, locationId: nil)
        let json = #"{"payload":{"properties":{"code":"main"},"slides":[{"image_url":"a.jpg"},{"banner_id":5},{"banner_id":6,"recommended_code":"other"}]}}"#
        let slider = try request.decode(Data(json.utf8))
        XCTAssertEqual(slider.banners.map(\.id), ["5", "6"], "a banner without banner_id cannot be tracked")
        XCTAssertEqual(slider.banners.map(\.code), ["main", "other"])
        XCTAssertEqual(slider.width, 0)
        XCTAssertThrowsError(try request.decode(Data()), "an answer without a body is not a slider")
        XCTAssertEqual(try request.decode(Data(#"{"payload":{}}"#.utf8)).banners.count, 0)
    }

    func test_the_sliders_fixture_is_proposed_until_the_contract_has_one() {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: ContractFixtures.url("sliders").path),
            "the contract has sliders.json now: copy it into contract-\(ContractFixtures.version) and remove the proposed one"
        )
    }

    static func json(slider: Slider) -> [String: Any] {
        [
            "code": slider.code, "width": slider.width, "height": slider.height,
            "banners": slider.banners.map { banner -> [String: Any] in
                [
                    "id": banner.id, "code": banner.code, "imageUrl": FixtureMatching.field(banner.imageUrl),
                    "url": FixtureMatching.field(banner.url), "deeplinkIos": FixtureMatching.field(banner.deeplinkIos),
                    "deeplinkAndroid": FixtureMatching.field(banner.deeplinkAndroid), "html": FixtureMatching.field(banner.html),
                ]
            },
        ]
    }
}
