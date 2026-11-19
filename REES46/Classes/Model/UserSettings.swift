import Foundation

public enum Gender: String{
    case male
    case female
}


/// The history of the customer's notifications, the answer of `GET notifications`:
/// `{"status": "success", "payload": {"messages": [...]}}`.
public struct UserPayloadResponse {

    /// The answer's `status`: `success`; `nil` when the answer has none.
    public var status: String?
    public var notifications: [UserNotificationsResponse]

    /// `json` is the whole answer, its messages under `payload`; messages at its top level are read too.
    init(json: [String: Any]) {
        let payload = json["payload"] as? [String: Any]
        let notificationsArray = payload?["messages"] as? [[String: Any]] ?? json["messages"] as? [[String: Any]] ?? []
        var notificationsTemp = [UserNotificationsResponse]()
        for item in notificationsArray {
            notificationsTemp.append(UserNotificationsResponse(json: item))
        }
        notifications = notificationsTemp
        status = json["status"] as? String
    }
}


/// A message the customer was sent, one of `payload.messages`.
public struct UserNotificationsResponse {
    
    public var type: String?
    public var codeId: String?
    public var dateString: String?
    public var dateSentAt: String?
    public var subject: String?
    public var bodyData: String?
    public var url: String?
    public var icon: String?
    public var picture: String?
    /// The names of the mailings when `campaign_id` is a list of `{"name": ...}`; the server sends the
    /// mailing's id as a number, read into `campaignId`.
    public var campaignsIds: [String]?
    /// The mailing's id, `campaign_id`; `nil` when it is not a whole number.
    public var campaignId: Int?
    /// The channel the message went by, `channel`: `email`, `mobile_push`, `web_push`, `sms`, …
    public var channel: String?
    /// What the customer did with the message: the server sends one object, `statistics`, read as the
    /// one element of the list; a list of them is read as it is.
    public var statistics: [UserNotificationsStatistics]
    
    init(json: [String: Any]) {
        self.type = json["type"] as? String ?? ""
        self.codeId = json["code"] as? String ?? ""
        self.dateString = json["date"] as? String ?? ""
        self.dateSentAt = json["sent_at"] as? String ?? ""
        self.subject = json["subject"] as? String ?? ""
        self.bodyData = json["body"] as? String ?? ""
        self.url = json["url"] as? String ?? ""
        self.icon = json["icon"] as? String ?? ""
        self.picture = json["picture"] as? String ?? ""
        self.channel = json["channel"] as? String
        
        if let campaignsArr = json["campaign_id"] as? [[String: Any]] {
            var campaigns = [String]()
            for item in campaignsArr {
                if let name = item["name"] as? String {
                    campaigns.append(name)
                }
            }
            self.campaignsIds = campaigns
        } else {
            self.campaignId = JSONNumber.double(json["campaign_id"]).flatMap { Int(exactly: $0) }
        }
        
        switch json["statistics"] {
        case let list as [[String: Any]]:
            statistics = list.map(UserNotificationsStatistics.init)
        case let object as [String: Any]:
            statistics = [UserNotificationsStatistics(json: object)]
        default:
            statistics = []
        }
    }
}


/// What the customer did with a message, each `nil` when the answer does not say.
public struct UserNotificationsStatistics {
    
    /// The message was opened.
    public let opened: Bool?
    /// A link of the message was followed.
    public let clicked: Bool?
    /// Sending the message hard-bounced.
    public let hardBounced: Bool?
    /// Sending the message soft-bounced.
    public let softBounced: Bool?
    /// The customer complained about the message (`email`).
    public let complained: Bool?
    /// The customer unsubscribed by the message's link.
    public let unsubscribed: Bool?
    /// A purchase was attributed to the message.
    public let purchased: Bool?

    /// The server's keys are `hard_bounced` and `soft_bounced`; `hardBounced` and `softBounced` are read too.
    init(json: [String: Any]) {
        opened = json["opened"] as? Bool
        clicked = json["clicked"] as? Bool
        hardBounced = (json["hard_bounced"] ?? json["hardBounced"]) as? Bool
        softBounced = (json["soft_bounced"] ?? json["softBounced"]) as? Bool
        complained = json["complained"] as? Bool
        unsubscribed = json["unsubscribed"] as? Bool
        purchased = json["purchased"] as? Bool
    }
}


/*
public enum SearchType: String {
    case full
    case instant
}
*/
