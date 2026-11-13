//
//  CorePackageTests.swift
//  REES46CoreTests
//
//  Core tests that need neither the demo app nor CocoaPods. Run on a simulator:
//  xcodebuild test -scheme REES46 -destination 'platform=iOS Simulator,name=<device>'
//

import XCTest
@testable import REES46

final class CorePackageTests: XCTestCase {

    func test_safe_json_refuses_what_is_not_json() {
        XCTAssertNotNil(SafeJSON.data(["a": [1, 2], "b": "c"]))
        XCTAssertNil(SafeJSON.data(["date": Date()]))
        XCTAssertNil(SafeJSON.data(["nan": Double.nan]))
    }

    func test_log_levels_are_ordered_from_debug_to_none() {
        XCTAssertEqual(LogLevel.allCases, [.debug, .info, .warning, .error, .none])
        XCTAssertLessThan(LogLevel.debug, LogLevel.error)
        XCTAssertEqual(Rees46Config(shopId: "a").logLevel, .warning)
    }

    func test_a_logger_drops_what_is_below_its_level() {
        let shop = "package-\(UUID().uuidString)"
        var codes: [String] = []
        let lock = NSLock()
        Rees46.setLogHandler { message in
            guard message.shopId == shop else { return }
            lock.lock(); codes.append(message.code); lock.unlock()
        }
        defer { Rees46.setLogHandler(nil) }

        let logger = SdkLogger(shopId: shop, level: .info)
        logger.debug("d", "debug")
        logger.info("i", "info")
        logger.error("e", "error")

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            lock.lock(); let done = codes.count == 2; lock.unlock()
            if done { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        lock.lock(); defer { lock.unlock() }
        XCTAssertEqual(codes, ["i", "e"])
    }

    func test_the_contract_fixtures_ship_with_the_package_tests() throws {
        for name in ["init", "tracking"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/contract-0"))
            let fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            XCTAssertEqual(fixture["contract"] as? String, "0")
            XCTAssertFalse((fixture["cases"] as? [Any] ?? []).isEmpty)
        }
    }
}
