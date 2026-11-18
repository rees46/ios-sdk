//
//  AgentSearchModels.swift
//  REES46
//
//  The models of the search agent, the AI search of `search` (`sdk/contract/search.md`): the dialog of
//  the customer with the agent, its sessions, messages and the products the agent offers.
//

import Foundation

@_spi(Bridge)
extension Rees46 {

    /// The customer's dialog with the agent (`search.agentDialog`).
    public struct AgentDialogResponse: Equatable {
        /// The last 20 sessions, the latest first, without their messages; none is an empty list.
        public let sessions: [AgentSession]
        /// The session asked for, or the latest one, with its messages; `nil` while the customer has
        /// none.
        public let session: AgentSession?
    }

    /// The agent's answer to a message (`search.agent`).
    public struct AgentResponse: Equatable {
        /// The session the message went to — a new one without a `sessionId` —, without its messages.
        public let session: AgentSession
        /// The agent's answer.
        public let message: AgentMessage
    }

    /// A session of the dialog; `id` is 64-bit, as the server's ids of sessions.
    public struct AgentSession: Equatable {
        public let id: Int
        /// The start of the customer's first message.
        public let title: String?
        /// The time of the last message, ISO 8601 as the answer has it.
        public let updatedAt: String?
        /// Empty where the answer gives the session without them: in the list of sessions and in
        /// `AgentResponse`.
        public let messages: [AgentMessage]
    }

    /// A message of the dialog; `id` is 64-bit, as the server's ids of messages.
    public struct AgentMessage: Equatable {
        public let id: Int?
        public let role: AgentMessageRole?
        public let content: String?
        /// ISO 8601 as the answer has it.
        public let createdAt: String?
        /// The products the agent offered; empty for the customer's messages.
        public let products: [AgentProduct]
    }

    /// Who wrote a message. An open set: a role the server adds comes as it is.
    public struct AgentMessageRole: RawRepresentable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The customer.
        public static let user = AgentMessageRole(rawValue: "user")
        /// The agent.
        public static let assistant = AgentMessageRole(rawValue: "assistant")
    }

    /// A product the agent offered: not a `Product`, a short one of its own with why it fits.
    ///
    /// The server loads the products of the history anew on every `agentDialog`: one no longer in stock
    /// is gone, a price is today's.
    public struct AgentProduct: Equatable {
        public let id: String
        public let name: String?
        /// In the customer's location when the server knows it.
        public let price: Double?
        /// `nil` when the product has none: the server's 0 too.
        public let oldPrice: Double?
        public let priceFormatted: String?
        public let oldPriceFormatted: String?
        public let picture: String?
        /// With the attribution of the agent (`recommended_by=agent_search&recommended_code=<session>`);
        /// `nil` when the product has no absolute link.
        public let url: String?
        /// Why the product fits the request; empty when the agent gave no reason.
        public let reason: String
    }
}

// MARK: - Answers

extension Rees46.AgentDialogResponse: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        sessions = answer.models(Rees46.AgentSession.self, "sessions") ?? []
        session = answer.model(Rees46.AgentSession.self, "session")
    }
}

extension Rees46.AgentResponse: AnswerReadable {

    /// Without its session or the agent's message it is not the agent's answer (`decoding`).
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        guard let session = answer.model(Rees46.AgentSession.self, "session"),
              let message = answer.model(Rees46.AgentMessage.self, "message")
        else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: answer.codingPath, debugDescription: "no session or message"))
        }
        self.session = session
        self.message = message
    }
}

extension Rees46.AgentSession: AnswerReadable {

    /// A session without an id is left out: the dialog cannot go on in it.
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        guard let id = answer.lenientInt("id") else {
            throw DecodingError.keyNotFound(AnswerKey("id"), DecodingError.Context(codingPath: answer.codingPath, debugDescription: "no id"))
        }
        self.id = id
        title = answer.lenientString("title")
        updatedAt = answer.lenientString("updated_at")
        messages = answer.models(Rees46.AgentMessage.self, "messages") ?? []
    }
}

extension Rees46.AgentMessage: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        id = answer.lenientInt("id")
        role = answer.lenientString("role").map(Rees46.AgentMessageRole.init(rawValue:))
        content = answer.lenientString("content")
        createdAt = answer.lenientString("created_at")
        products = answer.models(Rees46.AgentProduct.self, "products") ?? []
    }
}

extension Rees46.AgentProduct: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        id = try answer.requiredString("id")
        name = answer.lenientString("name")
        price = answer.lenientDouble("price")
        // No old price is 0.0 in the answer.
        oldPrice = answer.lenientDouble("oldprice").flatMap { $0 > 0 ? $0 : nil }
        priceFormatted = answer.lenientString("price_formatted")
        oldPriceFormatted = answer.lenientString("oldprice_formatted")
        picture = answer.lenientString("picture")
        url = answer.lenientString("url")
        reason = answer.lenientString("reason") ?? ""
    }
}

/// Whether the shop turned the search agent on: `search.blank_mode` of the instance's last `/init`
/// answer is `agent`. Written by the `/init` of the new core, read from any thread.
final class AgentSearchSwitch {

    private let lock = NSLock()
    private var on = false

    var isOn: Bool {
        lock.lock(); defer { lock.unlock() }
        return on
    }

    /// The `blank_mode` of an answer: any value but `agent`, and none, is the usual empty search.
    func adopt(blankMode: String?) {
        lock.lock()
        on = blankMode == "agent"
        lock.unlock()
    }
}
