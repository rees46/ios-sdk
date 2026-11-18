//
//  LoyaltyAPI.swift
//  REES46
//
//  The `loyalty` namespace of the contract (`sdk/contract/loyalty.md`).
//

import Foundation

/**
 The loyalty program from the customer's side: join it, read one's status, get the promotions that fit.
 The rest of the program — bonuses, certificates, checkout, promo codes — is the shop's server's: it
 needs the shop's secret, which the SDK never sends.

 Without the secret the server takes `join` and `getStatus` only from a shop with "loyalty methods from
 the front" turned on in its account (off by default); otherwise they end as `http(403)`. Whether they
 stay so is open (questions 17 and 18 of `sdk/questions.md`). `getPromotions` needs no such setting.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.

 Every `completion` is called once, on the main thread, with the value or the error: `invalidArgument`
 for an argument the method refuses, nothing sent; `notInitialized` on the old core or after
 `release()`, `shopBlocked`, `network`, `timeout`, `http(code:serverCode:)` — `404` when the shop has
 no loyalty program, `402` when the service is off or not paid, `403` when the method needs the secret,
 `400` for data the server refuses —, `decoding` for an answer that is not the method's, `cancelled`
 for a call `release()` ended. Nothing is repeated: the app decides. The `async` forms throw the
 `Rees46.SdkError`; cancelling the task ends the call as `cancelled`.
 */
@_spi(Bridge)
public protocol LoyaltyAPI {

    /**
     Joins the customer to the program (`POST loyalty/members/join`) by their `phone`, which becomes
     the member's identifier for `getStatus`. A phone already registered is a success with the same
     identifier; the server then updates the name, gender and birthday it has. The server finds or makes
     the customer by the phone, not by the device.

     `invalidArgument` for an empty `phone` or a `birthday` that is not an existing date `YYYY-MM-DD`:
     a birthday the server cannot read erases the one it has. An empty name is not sent.
     */
    func join(
        phone: String,
        firstName: String?,
        lastName: String?,
        gender: Gender?,
        birthday: String?,
        completion: @escaping (Result<LoyaltyMember, Rees46.SdkError>) -> Void
    )

    /// `join(phone:firstName:lastName:gender:birthday:completion:)` for `async` code.
    func join(phone: String, firstName: String?, lastName: String?, gender: Gender?, birthday: String?) async throws -> LoyaltyMember

    /**
     Whether the customer with `phone` is a member, and on which level (`GET loyalty/members/status`).
     Not a member is a success with `isMember` false; the base level is a member without a `level`. The
     phone goes as it is: the server keeps its digits. `invalidArgument` for an empty `phone`.
     */
    func getStatus(phone: String, completion: @escaping (Result<LoyaltyStatus, Rees46.SdkError>) -> Void)

    /// `getStatus(phone:completion:)` for `async` code.
    func getStatus(phone: String) async throws -> LoyaltyStatus

    /**
     The active promotions that fit the customer of this device and their cart
     (`GET loyalty/promos/for-client`); none is an empty list.

     `locationId` is the shop's location — a city, a store —, `promoCodes` the customer's codes,
     `chargeBonuses` whether bonuses are charged (the server takes `false` without it), `currentTime`
     the local time at the store as `HH:MM`, for the promotions of some hours (the server takes its
     own time in the shop's time zone without it). `invalidArgument` for a `currentTime` that is not
     `HH:MM` or an empty code in `promoCodes`. An empty `locationId` or list is not sent.
     */
    func getPromotions(
        locationId: String?,
        promoCodes: [String]?,
        chargeBonuses: Bool?,
        currentTime: String?,
        completion: @escaping (Result<[LoyaltyPromotion], Rees46.SdkError>) -> Void
    )

    /// `getPromotions(locationId:promoCodes:chargeBonuses:currentTime:completion:)` for `async` code.
    func getPromotions(locationId: String?, promoCodes: [String]?, chargeBonuses: Bool?, currentTime: String?) async throws -> [LoyaltyPromotion]
}

/// The default arguments of `LoyaltyAPI`: a requirement of a protocol cannot have them.
@_spi(Bridge)
extension LoyaltyAPI {

    public func join(
        phone: String,
        firstName: String? = nil,
        lastName: String? = nil,
        gender: Gender? = nil,
        birthday: String? = nil,
        completion: @escaping (Result<LoyaltyMember, Rees46.SdkError>) -> Void
    ) {
        join(phone: phone, firstName: firstName, lastName: lastName, gender: gender, birthday: birthday, completion: completion)
    }

    public func join(
        phone: String,
        firstName: String? = nil,
        lastName: String? = nil,
        gender: Gender? = nil,
        birthday: String? = nil
    ) async throws -> LoyaltyMember {
        try await join(phone: phone, firstName: firstName, lastName: lastName, gender: gender, birthday: birthday)
    }

    public func getPromotions(
        locationId: String? = nil,
        promoCodes: [String]? = nil,
        chargeBonuses: Bool? = nil,
        currentTime: String? = nil,
        completion: @escaping (Result<[LoyaltyPromotion], Rees46.SdkError>) -> Void
    ) {
        getPromotions(locationId: locationId, promoCodes: promoCodes, chargeBonuses: chargeBonuses, currentTime: currentTime, completion: completion)
    }

    public func getPromotions(
        locationId: String? = nil,
        promoCodes: [String]? = nil,
        chargeBonuses: Bool? = nil,
        currentTime: String? = nil
    ) async throws -> [LoyaltyPromotion] {
        try await getPromotions(locationId: locationId, promoCodes: promoCodes, chargeBonuses: chargeBonuses, currentTime: currentTime)
    }
}

/// A member of the loyalty program.
@_spi(Bridge)
public struct LoyaltyMember {
    /// The member's identifier: the phone's digits, `7XXXXXXXXXX`.
    public let identifier: String
}

/// Whether the customer is a member, and their level.
@_spi(Bridge)
public struct LoyaltyStatus {
    public let isMember: Bool
    /// `nil` on the base level and for one who is not a member. `code` is always set.
    public let level: LoyaltyLevel?
}

/// A promotion of the loyalty program; `id` is 64-bit, as the server's ids of promotions.
@_spi(Bridge)
public struct LoyaltyPromotion {
    public let id: Int
    public let name: String
    public let description: String?
    /// `YYYY-MM-DD`.
    public let startDate: String?
    /// `YYYY-MM-DD`.
    public let finishDate: String?
    /// Where the promotion holds; `nil` is everywhere.
    public let stream: String?
    /// The text of the badge.
    public let badgeLabel: String?
    /// The colour of the badge, `#RRGGBB`.
    public let badgeColor: String?
    /// `nil` for a type the SDK does not know.
    public let rewardType: LoyaltyRewardType?
}

/// What a promotion gives.
@_spi(Bridge)
public enum LoyaltyRewardType: String {
    case discount = "discount"
    case bonusesEarn = "bonuses_earn"
    case bonusesUsage = "bonuses_usage"
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The loyalty program from the customer's side (`LoyaltyAPI`): on the new core only.
    public var loyalty: LoyaltyAPI {
        LoyaltyAPIImpl(requests: NamespaceRequests(self))
    }
}
