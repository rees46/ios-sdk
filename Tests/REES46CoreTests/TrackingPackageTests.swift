//
//  TrackingPackageTests.swift
//  REES46CoreTests
//
//  The rules of `tracking` that need no server (`sdk/contract/tracking.md`): the slides `track/stories`
//  takes, the sources an event refuses, and the result the `async` forms tell from a service.
//

import XCTest
@testable import REES46

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

    func test_the_sources_of_a_mailing_are_not_sources_of_an_event() {
        XCTAssertEqual(TrackingAPIImpl.notOfAnEvent, [.transactional, .webPushDigest])
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
