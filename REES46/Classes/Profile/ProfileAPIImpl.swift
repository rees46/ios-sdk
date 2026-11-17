//
//  ProfileAPIImpl.swift
//  REES46
//

import Foundation

struct ProfileAPIImpl: ProfileAPI {

    let requests: NamespaceRequests
    /// The instance whose popups v3 hear that the profile changed.
    weak var popups: SimplePersonalizationSDK?

    func get(completion: @escaping (Result<Rees46.Profile, Rees46.SdkError>) -> Void) {
        requests.call("profile.get", completion: completion) { Self.profileRequest }
    }

    func get() async throws -> Rees46.Profile {
        try await requests.value("profile.get") { Self.profileRequest }
    }

    func set(_ request: Rees46.ProfileUpdateRequest, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        requests.call("profile.set", completion: completion) { try changing(Self.setRequest(request)) }
    }

    func set(_ request: Rees46.ProfileUpdateRequest) async throws {
        try await requests.value("profile.set") { try changing(Self.setRequest(request)) }
    }

    func getLastOrder(completion: @escaping (Result<[Rees46.Product], Rees46.SdkError>) -> Void) {
        requests.call("profile.getLastOrder", completion: completion) { Self.lastOrderRequest }
    }

    func getLastOrder() async throws -> [Rees46.Product] {
        try await requests.value("profile.getLastOrder") { Self.lastOrderRequest }
    }

    /// `request` once it is on its way: popups v3 load their list anew for a profile new in the session,
    /// as for the old `setProfileData`.
    private func changing(_ request: ApiRequest<Void>) -> ApiRequest<Void> {
        popups?.popupsV3.contextChanged("profile", signature: ClientBody.signature(request.body))
        return request
    }

    // MARK: - Requests

    /// `GET profile`: the profile of the device's customer. An answer without a body has no field.
    static var profileRequest: ApiRequest<Rees46.Profile> {
        ApiRequest(method: .get, path: "profile") { body in
            try Readable<Rees46.Profile>.read(body.isEmpty ? Data("{}".utf8) : body)
        }
    }

    /// `POST profile/set` with the fields the request gives, its custom properties at the top level.
    static func setRequest(_ request: Rees46.ProfileUpdateRequest) throws -> ApiRequest<Void> {
        var body = ClientBody()
        try body.identifier("email", request.email, "email")
        try body.identifier("phone", request.phone, "phone")
        try body.identifier("id", request.externalId, "externalId")
        body.set("external_id", request.externalId)
        try body.identifier("loyalty_id", request.loyaltyId, "loyaltyId")
        try body.identifier("telegram_id", request.telegramId, "telegramId")
        body.set("fb_id", request.fbId)
        body.set("vk_id", request.vkId)
        body.set("first_name", request.firstName)
        body.set("last_name", request.lastName)
        body.set("gender", request.gender?.wire)
        if let birthday = request.birthday {
            body.set("birthday", try ClientBody.date(birthday, "birthday"))
        }
        if let age = request.age {
            guard age >= 0 else { throw Rees46.SdkError.invalidArgument("age is negative") }
            body.set("age", age)
        }
        body.set("location", request.location)
        if let kids = request.kids, !kids.isEmpty {
            body.set("kids", try kids.map { kid -> [String: Any] in
                var fields: [String: Any] = [:]
                fields["gender"] = kid.gender?.wire
                fields["birthday"] = try kid.birthday.map { try ClientBody.date($0, "the birthday of a kid") }
                return fields
            })
        }
        if let cars = request.cars, !cars.isEmpty {
            body.set("auto", cars.map { car -> [String: Any] in
                var fields: [String: Any] = [:]
                fields["brand"] = car.brand
                fields["model"] = car.model
                fields["vds"] = car.vds
                return fields
            })
        }
        try body.customProperties(request.customProperties)
        guard !body.fields.isEmpty else {
            throw Rees46.SdkError.invalidArgument("the request sets no field of the profile")
        }
        return ApiRequest(method: .post, path: "profile/set", body: body.fields) { _ in () }
    }

    /// `GET orders/last_for_user`: a list of products at the top of the answer; no order is an empty
    /// one, and so is an answer without a body. An answer that is not a list is `decoding`.
    static var lastOrderRequest: ApiRequest<[Rees46.Product]> {
        ApiRequest(method: .get, path: "orders/last_for_user") { body in
            guard !body.isEmpty else { return [] }
            return try Readable<Rees46.Product>.readList(body)
        }
    }
}

extension Gender {

    /// The value on the wire: `m`, `f`.
    var wire: String {
        switch self {
        case .male: return "m"
        case .female: return "f"
        }
    }

    /// The value of an answer; one the SDK does not know is none.
    init?(wire: String?) {
        switch wire?.lowercased() {
        case "m", "male": self = .male
        case "f", "female": self = .female
        default: return nil
        }
    }
}

extension Rees46.Profile: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        id = answer.lenientString("id")
        hasEmail = answer.lenientBool("has_email")
        emailRegisteredAt = answer.lenientString("email_registered_at")
        gender = Gender(wire: answer.lenientString("gender"))
        computedGender = Gender(wire: answer.lenientString("computed_gender"))
        boughtSomething = answer.lenientBool("bought_something")
        customProperties = answer.lenient(AnyJSON.self, "custom_properties")?.value as? [String: Any]
    }
}

/// Any JSON value: a map, a list, a string, a number, a boolean or `NSNull`.
struct AnyJSON: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        if let object = try? decoder.container(keyedBy: AnswerKey.self) {
            var map: [String: Any] = [:]
            for key in object.allKeys {
                map[key.stringValue] = (try? object.decode(AnyJSON.self, forKey: key))?.value ?? NSNull()
            }
            value = map
            return
        }
        if var list = try? decoder.unkeyedContainer() {
            var items: [Any] = []
            while !list.isAtEnd {
                guard let item = try? list.decode(AnyJSON.self) else { break }
                items.append(item.value)
            }
            value = items
            return
        }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            value = NSNull()
        } else if let flag = try? single.decode(Bool.self) {
            value = flag
        } else if let number = try? single.decode(Int.self) {
            value = number
        } else if let number = try? single.decode(Double.self) {
            value = number
        } else {
            value = try single.decode(String.self)
        }
    }
}
