import Foundation

/// Response for the `loyalty/members/status` request.
///
/// Envelope: `{ "status": ..., "payload": { "member": Bool, "level": { name, code, expiration_date } } }`.
public struct LoyaltyStatusResponse {
    public var status: String?
    public var member: Bool?
    public var level: LoyaltyLevel?

    init(json: [String: Any]) {
        status = json["status"] as? String
        let payload = json["payload"] as? [String: Any]
        member = payload?["member"] as? Bool
        if let levelJson = payload?["level"] as? [String: Any] {
            level = LoyaltyLevel(json: levelJson)
        }
    }
}

/// Loyalty level returned inside `loyalty/members/status` payload.
public struct LoyaltyLevel {
    public var name: String?
    public var code: String?
    public var expirationDate: String?

    init(json: [String: Any]) {
        name = json["name"] as? String
        code = json["code"] as? String
        expirationDate = json["expiration_date"] as? String
    }
}
