//
//  AgentSearchPackageTests.swift
//  REES46CoreTests
//
//  The search agent of `search` without a server, beyond the cases of `search.json`: its requests go to
//  the host of API v3, a message with the read timeout of the agent, and the length of a message counts
//  as the server counts it.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class AgentSearchPackageTests: XCTestCase {

    func test_the_agents_requests_go_to_the_host_of_api_v3() throws {
        let dialog = SearchAPIImpl.agentDialogRequest(sessionId: nil, locations: nil)
        XCTAssertEqual(dialog.host, .app)
        XCTAssertNil(dialog.timeout, "the dialog has the common timeout")
        let message = try SearchAPIImpl.agentRequest(message: "hi", sessionId: 12, locations: [])
        XCTAssertEqual(message.host, .app)
        XCTAssertEqual(message.method, .post)
        XCTAssertEqual(message.timeout, 60)
        XCTAssertNil(message.body["location"], "an empty list is none")
        XCTAssertEqual(message.body["session_id"] as? Int, 12)
        // The rest of search stays on the API host.
        XCTAssertEqual(SearchAPIImpl.blankRequest.host, .api)
        XCTAssertEqual(try SearchAPIImpl.fullRequest(query: "q", Rees46.SearchFullRequest()).host, .api)
    }

    func test_a_message_is_counted_in_unicode_scalars_as_the_server_counts_it() {
        XCTAssertNoThrow(try SearchAPIImpl.agentRequest(message: String(repeating: "я", count: 500), sessionId: nil, locations: nil))
        XCTAssertThrowsError(try SearchAPIImpl.agentRequest(message: String(repeating: "я", count: 501), sessionId: nil, locations: nil))
        // A flag is one character on screen and two scalars on the server.
        XCTAssertThrowsError(try SearchAPIImpl.agentRequest(message: String(repeating: "🇷🇺", count: 251), sessionId: nil, locations: nil))
        XCTAssertNoThrow(try SearchAPIImpl.agentRequest(message: String(repeating: "🇷🇺", count: 250), sessionId: nil, locations: nil))
    }

    func test_a_message_without_an_id_has_none_and_never_zero() throws {
        let request = try SearchAPIImpl.agentRequest(message: "hi", sessionId: nil, locations: nil)
        for message in [#"{"role":"assistant"}"#, #"{"id":null}"#, #"{"id":""}"#, #"{"id":"x"}"#, #"{"id":true}"#, #"{"id":{}}"#] {
            let answer = try request.decode(Data(#"{"session":{"id":13},"message":\#(message)}"#.utf8))
            XCTAssertNil(answer.message.id, message)
        }
        let dialog = SearchAPIImpl.agentDialogRequest(sessionId: nil, locations: nil)
        let history = try dialog.decode(Data(#"{"session":{"id":13,"messages":[{"role":"user","content":"a"},{"id":7}]}}"#.utf8))
        XCTAssertEqual(history.session?.messages.map(\.id), [nil, 7])
        XCTAssertEqual(try request.decode(Data(#"{"session":{"id":13},"message":{"id":0}}"#.utf8)).message.id, 0, "the server's own 0 stays")
        XCTAssertEqual(try request.decode(Data(#"{"session":{"id":13},"message":{"id":"3000000012"}}"#.utf8)).message.id, 3_000_000_012)
    }

    func test_the_switch_of_the_agent_follows_blank_mode() {
        let agent = AgentSearchSwitch()
        XCTAssertFalse(agent.isOn, "no answer of /init")
        agent.adopt(blankMode: "agent")
        XCTAssertTrue(agent.isOn)
        agent.adopt(blankMode: nil)
        XCTAssertFalse(agent.isOn)
        agent.adopt(blankMode: "Agent")
        XCTAssertFalse(agent.isOn, "the value as the server writes it")
        XCTAssertEqual(InitResponse(json: ["search": ["blank_mode": "agent"]]).search.blankMode, "agent")
        XCTAssertNil(InitResponse(json: [:]).search.blankMode)
    }
}
