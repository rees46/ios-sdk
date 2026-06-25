import Foundation

/// Response for the `GET /profile` request.
///
/// Returns the stored user profile. Only the most common fields are typed; the
/// open-ended `custom_properties` map is kept as a raw dictionary because its
/// shape is shop-specific.
public struct GetProfileResponse {
    public var id: String?
    public var email: String?
    public var phone: String?
    public var firstName: String?
    public var lastName: String?
    public var hasEmail: Bool?
    public var emailRegisteredAt: String?
    public var gender: String?
    public var computedGender: String?
    public var boughtSomething: Bool?
    public var customProperties: [String: Any]

    init(json: [String: Any]) {
        id = json["id"] as? String
        email = json["email"] as? String
        phone = json["phone"] as? String
        firstName = json["first_name"] as? String
        lastName = json["last_name"] as? String
        hasEmail = json["has_email"] as? Bool
        emailRegisteredAt = json["email_registered_at"] as? String
        gender = json["gender"] as? String
        computedGender = json["computed_gender"] as? String
        boughtSomething = json["bought_something"] as? Bool
        customProperties = json["custom_properties"] as? [String: Any] ?? [:]
    }
}
