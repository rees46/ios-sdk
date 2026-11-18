//
//  LogContractTests.swift
//  REES46Tests
//
//  The codes and the reasons the SDK logs are the ones of the table of `sdk/core/logging.md`: read from
//  the contract's file (its copy in the fixtures, checked against the contract when it is checked out
//  next to this repository), never from a list of the tests' own.
//

import UIKit
import XCTest
@_spi(Bridge) @testable import REES46

/// The table of codes of `sdk/core/logging.md`.
enum LogContract {

    struct Row {
        let code: String
        /// The reasons the row lists for `context.reason`; empty when it lists none.
        let reasons: Set<String>
        /// Whether the list of reasons is open (it ends with `…`).
        let openReasons: Bool
    }

    static func url() -> URL {
        ContractFixtures.url("logging", extension: "md")
    }

    /// The contract's own file, when the contract is checked out next to this repository.
    static func contractURL(sourceFile: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(sourceFile)")
            .deletingLastPathComponent()   // Rees46DemoTests
            .deletingLastPathComponent()   // DemoApp
            .deletingLastPathComponent()   // repository root
            .deletingLastPathComponent()
            .appendingPathComponent("documentation-unified/sdk/core/logging.md")
    }

    static let rows: [String: Row] = {
        guard let text = try? String(contentsOf: url(), encoding: .utf8) else { return [:] }
        var rows: [String: Row] = [:]
        for line in text.components(separatedBy: "\n") where line.hasPrefix("| `") {
            let cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 4, let code = ticked(cells[1]).first else { continue }
            var reasons = Set<String>()
            var open = false
            let rest = cells[2...].joined(separator: "|")
            let spans = ticked(rest)
            if let index = spans.firstIndex(where: { $0.hasPrefix("context.reason") }) {
                // The reasons follow the span that names them; `…` after them leaves the list open.
                reasons.formUnion(spans[(index + 1)...])
                open = rest.range(of: "context.reason").map { rest[$0.upperBound...].contains("…") } ?? false
            }
            if cells[2].contains("(`") {
                // `popup_not_shown`: the reasons it lists in its level column.
                reasons.formUnion(ticked(cells[2]).filter { !["debug", "info", "warning", "error"].contains($0) })
            }
            rows[code] = Row(code: code, reasons: reasons, openReasons: open)
        }
        // Below the table: the area codes, and the reason of a request that failed offline.
        for area in ["sdk_log", "ui", "stories", "stories_v3", "popups_v3", "push"] where text.contains("`\(area)`") {
            rows[area] = Row(code: area, reasons: [], openReasons: true)
        }
        if text.contains("`request_failed` с `context.reason = offline`"), let failed = rows["request_failed"] {
            rows["request_failed"] = Row(code: failed.code, reasons: failed.reasons.union(["offline"]), openReasons: false)
        }
        return rows
    }()

    static func reasons(of code: String) -> Set<String> {
        rows[code]?.reasons ?? []
    }

    /// Whether `message`'s code is in the table, and its reason one the row lists.
    static func allows(_ message: Rees46.SdkLogMessage) -> Bool {
        guard let row = rows[message.code] else { return false }
        guard let reason = message.context["reason"] else { return true }
        return row.openReasons || row.reasons.contains(reason)
    }

    private static func ticked(_ text: String) -> [String] {
        text.components(separatedBy: "`").enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
    }
}

final class LogContractTests: CoreScenarioTestCase {

    func test_the_copy_of_the_table_is_the_contracts_file() throws {
        let copy = try Data(contentsOf: LogContract.url())
        XCTAssertFalse(LogContract.rows.isEmpty, "the table parses")
        let contract = LogContract.contractURL()
        guard FileManager.default.fileExists(atPath: contract.path) else {
            throw XCTSkip("the contract is not checked out next to the repository")
        }
        XCTAssertEqual(copy, try Data(contentsOf: contract), "copy sdk/core/logging.md into the fixtures again")
    }

    func test_every_code_of_the_sdk_is_in_the_table() {
        for code in LogCode.all {
            XCTAssertNotNil(LogContract.rows[code], "\(code) is not in sdk/core/logging.md")
        }
        for area in SdkLogger.Area.allCases {
            XCTAssertNotNil(LogContract.rows[area.rawValue], "\(area.rawValue)")
        }
    }

    func test_the_push_token_is_skipped_only_for_the_reasons_of_the_table() {
        XCTAssertEqual(LogContract.reasons(of: "push_token_skipped"), ["sent_recently", "no_device_id", "auto_send_off", "push_only"])
        let shop = newShop()
        hold("/init")
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        // No did yet: it waits.
        sdk.submitPushToken(Rees46.PushToken(token: "t", provider: .apns), completion: nil)
        XCTAssertTrue(waitForLog(shop, "push_token_skipped", reason: "no_device_id"))
        release("/init")
        XCTAssertTrue(eventually { self.requests("/mobile_push_tokens", shop).count == 1 })
        XCTAssertTrue(eventually { sdk.storage.pushTokenSent(platform: "ios") != nil })
        // Within its week.
        sdk.submitPushToken(Rees46.PushToken(token: "t", provider: .apns), completion: nil)
        XCTAssertTrue(waitForLog(shop, "push_token_skipped", reason: "sent_recently"))
        // Another launch's send on its way.
        sdk.storage.setPushTokenClaim(ShopStorage.PushTokenClaim(token: "t2", since: clock.now()), platform: "ios")
        sdk.submitPushToken(Rees46.PushToken(token: "t2", provider: .apns), completion: nil)
        XCTAssertTrue(eventually { self.logged(shop, "push_token_skipped").filter { $0.context["reason"] == "sent_recently" }.count == 2 })
        assertInTable(shop)
        sdk.release()
    }

    func test_the_reasons_of_dropped_pushes_and_events_are_the_tables() {
        // Not a push of the SDK; an unknown shop; a shop without a did; a shop that refused.
        Rees46.handlePush(["title": "Hi"], event: .delivered)
        XCTAssertTrue(waitForLog(nil, "push_dropped", reason: "not_sdk_push"))
        Rees46.handlePush(pushPayload("unknown-\(UUID().uuidString)"), event: .delivered)
        XCTAssertTrue(waitForLog(nil, "push_dropped", reason: "unknown_shop"))
        let (empty, _) = registerPending(did: nil)
        Rees46.handlePush(pushPayload(empty), event: .delivered)
        XCTAssertTrue(waitForLog(empty, "push_dropped", reason: "no_did"))
        let (refused, storage) = registerPending(did: "d")
        storage.refused = true
        Rees46.handlePush(pushPayload(refused), event: .delivered)
        XCTAssertTrue(waitForLog(refused, "queue_dropped", reason: "refused"))
        assertInTable(nil)
        assertInTable(empty)
        assertInTable(refused)
    }

    func test_a_pushs_reroute_and_repeat_log_nothing_outside_the_table() {
        let shop = newShop()
        let old = makeV2(shop)
        old.release()
        let new = makeV2(shop)
        Rees46.deliver(.event(.clicked), type: "bulk", code: "m-1", payload: pushPayload(shop), to: old, shopId: shop)
        XCTAssertTrue(eventually { self.requests("/track/clicked", shop).count == 1 })
        Rees46.handlePush(pushPayload(shop), event: .clicked)
        XCTAssertTrue(eventually { self.logged(shop, "push_received").contains { $0.context["repeat"] == "true" } })
        XCTAssertTrue(logged(shop, "push_received").contains { $0.context["rerouted"] == "true" })
        assertInTable(shop)
        new.release()
    }

    func test_the_configs_a_shop_does_not_take_are_reasons_of_the_table() {
        let shop = newShop()
        let identity = knownIdentity(did: "own-did")
        let first = StubSDK.make(shopId: shop, identity: identity, logLevel: .debug, coreV2: true, deviceId: "app-did", environment: environment)
        XCTAssertTrue(waitForLog(shop, "invalid_config", reason: "device_id_kept"))
        XCTAssertTrue(LogContract.reasons(of: "invalid_config").isSuperset(of: ["device_id_kept", "already_initialized", "url_session_delegate"]))
        assertInTable(shop)
        first.release()
    }

    func test_a_popup_the_app_declines_or_does_not_present_is_popup_not_shown_with_its_reason() {
        final class Declining: PopupPresentationDelegate {
            let asked = Locked(0)
            func sdk(_ sdk: PersonalizationSDK, shouldPresentPopup popup: Popup) -> UIViewController? {
                asked.mutate { $0 += 1 }
                return nil
            }
        }
        PopupV3Slots.shared.reset()
        let shop = newShop()
        let popup = #"{"did":"d","seance":"s-1","popup":{"id":7,"html":"<p>x</p>"}}"#
        answer("/init", StubReply(json: popup))
        let declining = Declining()
        hold("/init")
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        sdk.popupPresentationDelegate = declining
        release("/init")
        XCTAssertTrue(waitForLog(shop, "popup_not_shown", reason: "app_declined"))
        XCTAssertEqual(logged(shop, "popup_not_shown").first?.level, .debug)
        sdk.release()

        // No delegate, and the stub SDK does not present popups by itself.
        let other = newShop()
        answer("/init", StubReply(json: popup))
        let quiet = makeV2(other, identity: InMemoryUserIdentityRepository())
        XCTAssertTrue(waitForLog(other, "popup_not_shown", reason: "auto_presentation_off"))
        assertInTable(shop)
        assertInTable(other)
        quiet.release()
    }

    /// Every message the handler heard for `shop` has a code and a reason of the table.
    private func assertInTable(_ shop: String?, file: StaticString = #filePath, line: UInt = #line) {
        for message in heard where message.shopId == shop {
            XCTAssertTrue(
                LogContract.allows(message),
                "\(message.code) \(message.context["reason"] ?? "") is not in sdk/core/logging.md",
                file: file, line: line
            )
        }
    }
}
