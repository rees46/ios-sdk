//
//  TrackingPackageTests.swift
//  REES46CoreTests
//
//  The rules of `tracking` that need no server (`sdk/contract/tracking.md`): the slides `track/stories`
//  takes, the sources an event refuses, and the result the `async` forms tell from a service.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class TrackingPackageTests: XCTestCase {

    func test_track_stories_takes_a_story_and_a_slide_that_are_positive_whole_numbers() {
        let taken = [("12", "34"), ("1", "007"), ("9223372036854775807", "1")]
        let virtual = [
            ("12_1", "1"), ("+12", "1"), (" 12", "1"), ("012", "1"), ("0", "1"), ("-3", "1"), ("١٢", "1"), ("", "1"),
            ("12", "+5"), ("12", " 5"), ("12", "0"), ("12", "00"), ("12", "5a"), ("12", "١"), ("12", ""),
        ]
        for (story, slide) in taken {
            XCTAssertFalse(TrackEventServiceImpl.isVirtualSlide(.slideView(storyId: story, slideId: slide)), "\(story)/\(slide)")
            XCTAssertFalse(TrackEventServiceImpl.isVirtualSlide(.slideClick(storyId: story, slideId: slide)), "\(story)/\(slide)")
        }
        for (story, slide) in virtual {
            XCTAssertTrue(TrackEventServiceImpl.isVirtualSlide(.slideView(storyId: story, slideId: slide)), "\(story)/\(slide)")
        }
        XCTAssertFalse(TrackEventServiceImpl.isVirtualSlide(.productView(id: "x")), "not a slide")
        XCTAssertEqual(TrackEventServiceImpl.storyNumber("12"), 12)
        XCTAssertNil(TrackEventServiceImpl.storyNumber("12 "))
    }

    func test_a_slide_goes_with_the_code_of_its_block_given_or_loaded_and_without_one_is_refused() {
        XCTAssertEqual(TrackEventServiceImpl.storiesBlockCode(given: "b", loaded: "l"), "b")
        XCTAssertEqual(TrackEventServiceImpl.storiesBlockCode(given: nil, loaded: "l"), "l")
        XCTAssertEqual(TrackEventServiceImpl.storiesBlockCode(given: " ", loaded: "l"), "l", "a blank code is none")
        XCTAssertNil(TrackEventServiceImpl.storiesBlockCode(given: nil, loaded: nil))
        XCTAssertNil(TrackEventServiceImpl.storiesBlockCode(given: "", loaded: " "))
        XCTAssertNotNil(TrackEventServiceImpl.missingStoriesCode(.slideView(storyId: "1", slideId: "2"), nil))
        XCTAssertNotNil(TrackEventServiceImpl.missingStoriesCode(.slideClick(storyId: "1", slideId: "2"), nil))
        XCTAssertNil(TrackEventServiceImpl.missingStoriesCode(.slideClick(storyId: "1", slideId: "2"), "b"))
        XCTAssertNil(TrackEventServiceImpl.missingStoriesCode(.productView(id: "1"), nil), "only a slide has a block")
    }

    func test_the_sources_of_a_mailing_are_not_sources_of_an_event() {
        XCTAssertEqual(TrackingAPIImpl.notOfAnEvent, [.transactional, .webPushDigest])
    }

    // MARK: - The bridges' raw source

    /// Every value of the contract's `TrackingSourceType` (`sdk/contract/tracking.md`), on the wire.
    static let contractSourceTypes = [
        "dynamic", "chain", "bulk", "transactional", "instant_search", "full_search", "stories", "web_push_digest",
        "slider", "agent_search",
    ]

    func test_a_bridge_source_goes_by_the_raw_value_of_each_type_of_the_contract() throws {
        for raw in Self.contractSourceTypes {
            let source = try TrackingSource(rawType: raw, code: "block-7")
            XCTAssertEqual(source.rawType, raw)
            XCTAssertEqual(source.code, "block-7")
            let codeField = raw == "web_push_digest" ? "web_push_digest_code" : "recommended_code"
            XCTAssertEqual(source.wire.params(), ["recommended_by": raw, codeField: "block-7"], raw)
            if let type = TrackingSourceType(rawValue: raw) {
                XCTAssertEqual(source.type, type, "a value of the public enum is its case")
            } else {
                XCTAssertEqual(source.type, .dynamic, "\(raw) is not a case before the major")
            }
        }
        XCTAssertEqual(TrackingSource.bridgeOnlyRawTypes, ["slider", "agent_search"])
        XCTAssertEqual(TrackingSource(type: .instantSearch, code: "q").rawType, "instant_search")
        XCTAssertEqual(TrackingSource(legacy: .chain, code: "c").wire.params()["recommended_by"], "chain")
    }

    func test_a_bridge_source_of_a_value_the_contract_does_not_have_is_invalid_argument() {
        for raw in ["", "instantSearch", "agentSearch", "SLIDER", " slider", "reputation", "popup", "web-push-digest"] {
            XCTAssertThrowsError(try TrackingSource(rawType: raw, code: "c"), raw) { error in
                guard case .invalidArgument? = error as? Rees46.SdkError else {
                    return XCTFail("\(raw): \(error)")
                }
            }
        }
    }

    func test_an_event_and_set_source_send_the_raw_value_of_a_bridge_source() async throws {
        let events = RecordingTrackService()
        let stored = RecordingSourceService()
        let tracking = TrackingAPIImpl(trackService: events, sourceService: stored)
        for raw in ["slider", "agent_search", "dynamic"] {
            let source = try TrackingSource(rawType: raw, code: "c-\(raw)")
            try await tracking.async.productView(itemId: "sku", source: source)
            try await tracking.async.addToCart(item: TrackingItem(id: "sku"), source: source)
            try await tracking.async.addToFavorites(itemId: "sku", source: source)
            try await tracking.async.purchase(
                PurchaseTrackingRequest(orderId: "o", orderPrice: 1, items: [PurchaseItemRequest(id: "sku", amount: 1, price: 1)]),
                source: source
            )
            tracking.setSource(source)
        }
        XCTAssertEqual(
            events.sources.map { $0?.type },
            ["slider", "slider", "slider", "slider", "agent_search", "agent_search", "agent_search", "agent_search", "dynamic", "dynamic", "dynamic", "dynamic"]
        )
        XCTAssertEqual(stored.stored.map(\.type), ["slider", "agent_search", "dynamic"])
        XCTAssertEqual(stored.stored.map(\.code), ["c-slider", "c-agent_search", "c-dynamic"])
    }

    func test_a_bridge_source_of_a_mailing_is_refused_with_an_event_and_stored_by_set_source() async throws {
        let events = RecordingTrackService()
        let stored = RecordingSourceService()
        let tracking = TrackingAPIImpl(trackService: events, sourceService: stored)
        for raw in ["transactional", "web_push_digest"] {
            let source = try TrackingSource(rawType: raw, code: "mail")
            do {
                try await tracking.async.productView(itemId: "sku", source: source)
                XCTFail("\(raw) went with an event")
            } catch let error as Rees46.SdkError {
                guard case .invalidArgument = error else { return XCTFail("\(raw): \(error)") }
            }
            tracking.setSource(source)
        }
        XCTAssertTrue(events.sources.isEmpty, "nothing was sent")
        XCTAssertEqual(stored.stored.map(\.type), ["transactional", "web_push_digest"])
    }

    func test_the_result_of_a_service_without_a_queue_is_its_answer() {
        var told: [Rees46.SdkError?] = []
        var heard = 0
        let completion = TrackingAnswer.telling({ told.append($0) }, { _ in heard += 1 })
        completion(.success(()))
        completion(.failure(.custom(error: "an empty id")))
        completion(.failure(.networkOfflineError))
        CurrentError.with(.http(code: 422, serverCode: nil)) { completion(.failure(.invalidResponse)) }
        XCTAssertEqual(told, [nil, .invalidArgument("an empty id"), .network, .http(code: 422, serverCode: nil)])
        XCTAssertEqual(heard, 4, "the old completion hears every answer as before")
    }
}

/// A service that keeps the source of each event it is given and answers it at once.
final class RecordingTrackService: TrackEventServiceProtocol {

    private(set) var sources: [TrackingSourceWire?] = []
    private(set) var events: [Event] = []
    private(set) var details: [TrackEventDetails] = []
    private(set) var custom: [[String: Any]?] = []

    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        track(event: event, source: recommendedBy.map(TrackingSourceWire.init), details: .none, completion: completion)
    }

    func track(event: Event, source: TrackingSourceWire?, details: TrackEventDetails, completion: @escaping (Result<Void, SdkError>) -> Void) {
        events.append(event)
        sources.append(source)
        self.details.append(details)
        completion(.success(()))
    }

    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackPurchase(request, source: recommendedBy.map(TrackingSourceWire.init), completion: completion)
    }

    func trackPurchase(_ request: PurchaseTrackingRequest, source: TrackingSourceWire?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        sources.append(source)
        completion(.success(()))
    }

    func trackEvent(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        custom.append(customFields)
        completion(.success(()))
    }

    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {
        completion(.success(()))
    }
}

/// A store of the source `setSource` sets, in memory.
final class RecordingSourceService: TrackSourceServiceProtocol {

    private(set) var stored: [(type: String, code: String)] = []

    func trackSource(source: RecommendedByCase, code: String) {
        trackSource(type: source.rawValue, code: code)
    }

    func trackSource(type: String, code: String) {
        stored.append((type, code))
    }
}
