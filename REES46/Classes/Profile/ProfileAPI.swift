//
//  ProfileAPI.swift
//  REES46
//
//  The `profile` namespace of the contract (`sdk/contract/profile.md`).
//

import Foundation

/**
 The customer's profile in the CDP: reading it, writing its properties, and the products of the last
 order. The server finds the customer by the device id; the SDK sends no secret of the shop, so reading
 gives only the profile's fields that are not sensitive.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.

 Every `completion` is called once, on the main thread, with the value or the error: `notInitialized` on
 the old core or after `release()`, `shopBlocked`, `invalidArgument` for an argument refused before
 anything is sent, `network`, `timeout`, `http(code:serverCode:)`, `decoding`, `cancelled` for a call
 `release()` ended. The `async` forms throw the same `Rees46.SdkError`, and cancelling the task ends the
 call as `cancelled`. Nothing is repeated: the app decides.
 */
@_spi(Bridge)
public protocol ProfileAPI {

    /// The customer's profile (`GET profile`): what the server gives without the shop's secret — no
    /// name, email or phone. A device the server does not know is `http(404)`.
    func get(completion: @escaping (Result<Rees46.Profile, Rees46.SdkError>) -> Void)

    func get() async throws -> Rees46.Profile

    /**
     Writes the properties of the profile (`POST profile/set`): only the fields given change. An empty
     text erases `externalId`, `telegramId`, `birthday`, `fbId` and `vkId`, and leaves `location`,
     `firstName` and `lastName` empty; `age` 0 erases the age. The server does not erase `email`,
     `phone` or `loyaltyId` with an empty text, so an empty one is refused. `gender` has no empty value:
     `set` cannot erase it.

     An identifier of another customer — `email`, `phone`, `externalId`, `loyaltyId`, `telegramId` —
     moves the device to that customer's profile: a sign-in, or another user on the same device. Call it
     on sign-in, when the city changes, and on every launch with the current identifier and city.

     Refused before anything is sent (`invalidArgument`): a request without a field, an empty `email`,
     `phone` or `loyaltyId`, a `birthday` — a kid's too — that is not an existing day `YYYY-MM-DD` of
     the years 1000 to 2999 (the server would ignore it in silence; an empty one erases it, but not a
     kid's), a negative `age`, a key of
     `customProperties` not of `[a-z0-9_]` or one of the request's own or the SDK's fields, a value of
     it that is not a string, a number, a boolean, `NSNull`, or a list or map of them. The server checks
     the email and the phone.
     */
    func set(_ request: Rees46.ProfileUpdateRequest, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void)

    func set(_ request: Rees46.ProfileUpdateRequest) async throws

    /// The products of the customer's last order (`GET orders/last_for_user`); no order is an empty
    /// list. A device the server does not know is `http(400)`.
    func getLastOrder(completion: @escaping (Result<[Rees46.Product], Rees46.SdkError>) -> Void)

    func getLastOrder() async throws -> [Rees46.Product]
}

@_spi(Bridge)
extension Rees46 {

    /// The customer's profile as the server gives it without the shop's secret. Which fields it has
    /// depends on the shop's settings; a field the answer does not have is `nil`.
    public struct Profile {
        /// The server's own id of the customer, not `externalId`.
        public let id: String?
        public let hasEmail: Bool?
        /// When the shop first got the email: `YYYY-MM-DD HH:MM:SS`, without a time zone.
        public let emailRegisteredAt: String?
        public let gender: Gender?
        /// The gender the server worked out.
        public let computedGender: Gender?
        public let boughtSomething: Bool?
        /// The shop's own properties of the profile, as the answer has them: strings, numbers, booleans,
        /// `NSNull`, lists and maps of them.
        public let customProperties: [String: Any]?
    }

    /// The properties `profile.set` writes: only the ones given change, `nil` is not sent.
    public struct ProfileUpdateRequest {
        public var email: String?
        public var phone: String?
        /// The customer's id in the shop's system; sent as both `id` and `external_id`.
        public var externalId: String?
        /// The id in an external loyalty program.
        public var loyaltyId: String?
        public var telegramId: String?
        public var fbId: String?
        public var vkId: String?
        public var firstName: String?
        public var lastName: String?
        public var gender: Gender?
        /// `YYYY-MM-DD` of the years 1000 to 2999: a date, not a moment, so no time zone moves it a day.
        /// An empty one erases it.
        public var birthday: String?
        /// From 0; 0 erases the age.
        public var age: Int?
        /// The city: an id of a location of the shop's feed.
        public var location: String?
        public var kids: [ProfileKid]?
        /// Sent as `auto`.
        public var cars: [ProfileCar]?
        /// The properties the shop made in its account, each sent at the top level of the request. A
        /// date goes as a string `YYYY-MM-DD`.
        public var customProperties: [String: Any]?

        public init(
            email: String? = nil,
            phone: String? = nil,
            externalId: String? = nil,
            loyaltyId: String? = nil,
            telegramId: String? = nil,
            fbId: String? = nil,
            vkId: String? = nil,
            firstName: String? = nil,
            lastName: String? = nil,
            gender: Gender? = nil,
            birthday: String? = nil,
            age: Int? = nil,
            location: String? = nil,
            kids: [ProfileKid]? = nil,
            cars: [ProfileCar]? = nil,
            customProperties: [String: Any]? = nil
        ) {
            self.email = email
            self.phone = phone
            self.externalId = externalId
            self.loyaltyId = loyaltyId
            self.telegramId = telegramId
            self.fbId = fbId
            self.vkId = vkId
            self.firstName = firstName
            self.lastName = lastName
            self.gender = gender
            self.birthday = birthday
            self.age = age
            self.location = location
            self.kids = kids
            self.cars = cars
            self.customProperties = customProperties
        }
    }

    /// A kid of the customer.
    public struct ProfileKid: Equatable {
        public var gender: Gender?
        /// `YYYY-MM-DD`.
        public var birthday: String?

        public init(gender: Gender? = nil, birthday: String? = nil) {
            self.gender = gender
            self.birthday = birthday
        }
    }

    /// A car of the customer.
    public struct ProfileCar: Equatable {
        public var brand: String?
        public var model: String?
        /// The API's documentation calls it the VIN.
        public var vds: String?

        public init(brand: String? = nil, model: String? = nil, vds: String? = nil) {
            self.brand = brand
            self.model = model
            self.vds = vds
        }
    }
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The customer's profile (`ProfileAPI`): on the new core only.
    public var profile: ProfileAPI {
        ProfileAPIImpl(requests: NamespaceRequests(self), popups: self as? SimplePersonalizationSDK)
    }
}
