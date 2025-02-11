import Foundation

public struct UserNotificationsResponse: Codable {
  
  public var type: String?
  public var codeId: String?
  public var dateString: String?
  public var dateSentAt: String?
  public var subject: String?
  public var bodyData: String?
  public var url: String?
  public var icon: String?
  public var picture: String?
  public var campaignsIds: [String]?
  public var statistics: [UserNotificationsStatistics]
  
  private enum CodingKeys: String, CodingKey {
    case type, subject, url, icon, picture, statistics
    case codeId = "code"
    case dateString = "date"
    case dateSentAt = "sent_at"
    case bodyData = "body"
    case campaignsIds = "campaign_id"
  }
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    type = try container.decodeIfPresent(String.self, forKey: .type)
    codeId = try container.decodeIfPresent(String.self, forKey: .codeId)
    dateString = try container.decodeIfPresent(String.self, forKey: .dateString)
    dateSentAt = try container.decodeIfPresent(String.self, forKey: .dateSentAt)
    subject = try container.decodeIfPresent(String.self, forKey: .subject)
    bodyData = try container.decodeIfPresent(String.self, forKey: .bodyData)
    url = try container.decodeIfPresent(String.self, forKey: .url)
    icon = try container.decodeIfPresent(String.self, forKey: .icon)
    picture = try container.decodeIfPresent(String.self, forKey: .picture)
    
    if let campaignsArray = try? container.decodeIfPresent([[String: String]].self, forKey: .campaignsIds) {
      campaignsIds = campaignsArray.compactMap { $0["name"] }
    } else {
      campaignsIds = []
    }
    
    statistics = try container.decode([UserNotificationsStatistics].self, forKey: .statistics)
    
  }
}
