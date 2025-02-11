import Foundation

public struct UserPayloadResponse: Codable {
  
  public var notifications: [UserNotificationsResponse]
  public enum CodingKeys: String, CodingKey {
    case notifications
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    notifications = try container.decode([UserNotificationsResponse].self, forKey: .notifications)
  }
}
