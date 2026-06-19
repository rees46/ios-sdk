import Foundation

/// Response for the `loyalty/members/join` request.
///
/// The endpoint returns an envelope `{ "status": "success" | "fail", "payload": { ... } }`.
/// `payload` is kept as a raw dictionary because its shape differs between success and failure.
public struct LoyaltyJoinResponse {
    public var status: String?
    public var payload: [String: Any]

    init(json: [String: Any]) {
        status = json["status"] as? String
        payload = json["payload"] as? [String: Any] ?? [:]
    }
}
