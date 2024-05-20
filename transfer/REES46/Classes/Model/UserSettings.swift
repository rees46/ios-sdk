import Foundation

public enum Gender: String{
    case male
    case female
}


public struct UserPayloadResponse {
    
    public var notifications: [UserNotificationsResponse]

    init(json: [String: Any]) {
        let notificationsArray = json["messages"] as? [[String: Any]] ?? []
        var notificationsTemp = [UserNotificationsResponse]()
        for item in notificationsArray {
            notificationsTemp.append(UserNotificationsResponse(json: item))
        }
        notifications = notificationsTemp
    }
}


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
    public var campaignsIds: [String]?
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
        
        if let campaignsArr = json["campaign_id"] as? [[String: Any]] {
            var campaigns = [String]()
            for item in campaignsArr {
                if let name = item["name"] as? String {
                    campaigns.append(name)
                }
            }
            self.campaignsIds = campaigns
        }
        
        let allStats = json["statistics"] as? [[String: Any]] ?? []
        var statItemsTemp = [UserNotificationsStatistics]()
        for item in allStats {
            statItemsTemp.append(UserNotificationsStatistics(json: item))
        }
        statistics = statItemsTemp
    }
}


public struct UserNotificationsStatistics {
    
    let opened: Bool?
    let clicked: Bool?
    let hardBounced: Bool?
    let softBounced: Bool?
    let complained: Bool?
    let unsubscribed: Bool?
    let purchased: Bool?

    init(json: [String: Any]) {
        opened = json["opened"] as? Bool
        clicked = json["clicked"] as? Bool
        hardBounced = json["hardBounced"] as? Bool
        softBounced = json["softBounced"] as? Bool
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
