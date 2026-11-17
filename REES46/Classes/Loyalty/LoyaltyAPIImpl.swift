//
//  LoyaltyAPIImpl.swift
//  REES46
//

import Foundation

struct LoyaltyAPIImpl: LoyaltyAPI {

    let requests: NamespaceRequests

    func join(
        phone: String,
        firstName: String?,
        lastName: String?,
        gender: Gender?,
        birthday: String?,
        completion: @escaping (Result<LoyaltyMember, Rees46.SdkError>) -> Void
    ) {
        requests.call("loyalty.join", completion: completion) {
            try Self.joinRequest(phone: phone, firstName: firstName, lastName: lastName, gender: gender, birthday: birthday)
        }
    }

    func join(phone: String, firstName: String?, lastName: String?, gender: Gender?, birthday: String?) async throws -> LoyaltyMember {
        try await requests.value("loyalty.join") {
            try Self.joinRequest(phone: phone, firstName: firstName, lastName: lastName, gender: gender, birthday: birthday)
        }
    }

    func getStatus(phone: String, completion: @escaping (Result<LoyaltyStatus, Rees46.SdkError>) -> Void) {
        requests.call("loyalty.getStatus", completion: completion) { try Self.statusRequest(phone: phone) }
    }

    func getStatus(phone: String) async throws -> LoyaltyStatus {
        try await requests.value("loyalty.getStatus") { try Self.statusRequest(phone: phone) }
    }

    func getPromotions(
        locationId: String?,
        promoCodes: [String]?,
        chargeBonuses: Bool?,
        currentTime: String?,
        completion: @escaping (Result<[LoyaltyPromotion], Rees46.SdkError>) -> Void
    ) {
        requests.call("loyalty.getPromotions", completion: completion) {
            try Self.promotionsRequest(locationId: locationId, promoCodes: promoCodes, chargeBonuses: chargeBonuses, currentTime: currentTime)
        }
    }

    func getPromotions(locationId: String?, promoCodes: [String]?, chargeBonuses: Bool?, currentTime: String?) async throws -> [LoyaltyPromotion] {
        try await requests.value("loyalty.getPromotions") {
            try Self.promotionsRequest(locationId: locationId, promoCodes: promoCodes, chargeBonuses: chargeBonuses, currentTime: currentTime)
        }
    }

    // MARK: - Requests

    /// `POST loyalty/members/join` with the member's fields; the core adds the common ones, the device id
    /// among them, which this address does not read. No email: the server reads it only with the secret.
    static func joinRequest(
        phone: String,
        firstName: String?,
        lastName: String?,
        gender: Gender?,
        birthday: String?
    ) throws -> ApiRequest<LoyaltyMember> {
        guard !ApiArguments.isBlank(phone) else {
            throw Rees46.SdkError.invalidArgument("the phone must not be empty")
        }
        // A birthday the server cannot read erases the one it has: only an existing date goes.
        if let birthday = birthday, !ApiArguments.isCalendarDate(birthday) {
            throw Rees46.SdkError.invalidArgument("the birthday must be an existing date as YYYY-MM-DD")
        }
        var body: [String: Any] = ["phone": phone]
        body["first_name"] = ApiArguments.given(firstName)
        body["last_name"] = ApiArguments.given(lastName)
        body["gender"] = gender.map { $0 == .male ? "m" : "f" }
        body["birthday"] = birthday
        return ApiRequest(method: .post, path: "loyalty/members/join", body: body) { data in
            try JSONDecoder().decode(LoyaltyMemberAnswer.self, from: data).member
        }
    }

    /// `GET loyalty/members/status` for the member `phone`, sent as it is: the server keeps its digits.
    static func statusRequest(phone: String) throws -> ApiRequest<LoyaltyStatus> {
        guard !ApiArguments.isBlank(phone) else {
            throw Rees46.SdkError.invalidArgument("the phone must not be empty")
        }
        return .get("loyalty/members/status", query: ["identifier": phone], answer: LoyaltyStatusAnswer.self) { $0.status }
    }

    /// `GET loyalty/promos/for-client` for the customer of the device id. The codes go as a list of
    /// Rails — `promo_codes[]=A&promo_codes[]=B` —: the server drops a string of them. No contacts: by a
    /// contact the server would give another customer's promotions. An answer without a body is none.
    static func promotionsRequest(
        locationId: String?,
        promoCodes: [String]?,
        chargeBonuses: Bool?,
        currentTime: String?
    ) throws -> ApiRequest<[LoyaltyPromotion]> {
        if let time = currentTime, !isTime(time) {
            throw Rees46.SdkError.invalidArgument("the current time must be HH:MM")
        }
        if promoCodes?.contains(where: ApiArguments.isBlank) == true {
            throw Rees46.SdkError.invalidArgument("a promo code must not be empty")
        }
        var query: [String: String] = [:]
        query["location_id"] = ApiArguments.given(locationId)
        query["charge_bonuses"] = chargeBonuses.map { $0 ? "true" : "false" }
        query["current_time"] = currentTime
        var request = ApiRequest<[LoyaltyPromotion]>.get(
            "loyalty/promos/for-client", query: query, answer: LoyaltyPromotionsAnswer.self, whenEmpty: []
        ) { $0.promotions }
        if let codes = promoCodes, !codes.isEmpty {
            request.queryLists = ["promo_codes[]": codes]
        }
        return request
    }

    // MARK: - Arguments

    /// `HH:MM` of a day: `00:00` to `23:59`.
    static func isTime(_ text: String) -> Bool {
        text.range(of: #"^([01][0-9]|2[0-3]):[0-5][0-9]$"#, options: .regularExpression) != nil
    }
}

// MARK: - The answers

/// `{"status": "success", "payload": {"message": …, "identifier": "7…"}}`, for a new member and for one
/// already registered. Without an identifier it is not a member (`decoding`).
struct LoyaltyMemberAnswer: Decodable {

    let member: LoyaltyMember

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnswerKey.self)
        let payload = try? root.nestedContainer(keyedBy: AnswerKey.self, forKey: "payload")
        guard let identifier = payload?.lenientString("identifier") else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "no payload.identifier"))
        }
        member = LoyaltyMember(identifier: identifier)
    }
}

/// `{"status": "success", "payload": {"member": true, "level": {"code", "name", "expiration_date"}}}`.
/// A level whose `code` is `null` — the base level, or no member — is none. Without `payload.member` it
/// is not a status (`decoding`).
struct LoyaltyStatusAnswer: Decodable {

    let status: LoyaltyStatus

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnswerKey.self)
        let payload = try? root.nestedContainer(keyedBy: AnswerKey.self, forKey: "payload")
        guard let isMember = payload?.lenientBool("member") else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "no payload.member"))
        }
        let level = try? payload?.nestedContainer(keyedBy: AnswerKey.self, forKey: "level")
        status = LoyaltyStatus(
            isMember: isMember,
            level: level.flatMap { level in
                level.lenientString("code").map {
                    LoyaltyLevel(code: $0, name: level.lenientString("name"), expirationDate: level.lenientString("expiration_date"))
                }
            }
        )
    }
}

/// `{"status": "success", "payload": {"promotions": [...]}}`. A promotion without an id is left out, one
/// of an unknown reward type has none. Without the list it is not an answer of promotions (`decoding`).
struct LoyaltyPromotionsAnswer: Decodable {

    let promotions: [LoyaltyPromotion]

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnswerKey.self)
        let payload = try? root.nestedContainer(keyedBy: AnswerKey.self, forKey: "payload")
        guard let list = payload?.lenientList(PromotionAnswer.self, "promotions") else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "no payload.promotions"))
        }
        promotions = list.map(\.promotion)
    }

    private struct PromotionAnswer: Decodable {
        let promotion: LoyaltyPromotion

        init(from decoder: Decoder) throws {
            let item = try decoder.container(keyedBy: AnswerKey.self)
            guard let id = item.lenientInt("id") else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "no id"))
            }
            promotion = LoyaltyPromotion(
                id: id,
                name: item.lenientString("name") ?? "",
                description: item.lenientString("description"),
                startDate: item.lenientString("start_date"),
                finishDate: item.lenientString("finish_date"),
                stream: item.lenientString("stream"),
                badgeLabel: item.lenientString("badge_label"),
                badgeColor: item.lenientString("badge_color"),
                rewardType: item.lenientEnum(LoyaltyRewardType.self, "reward_type")
            )
        }
    }
}

extension LoyaltyLevel {

    /// A level of `loyalty.getStatus`, whose `code` is always set.
    init(code: String, name: String?, expirationDate: String?) {
        self.init(json: [:])
        self.code = code
        self.name = name
        self.expirationDate = expirationDate
    }
}
