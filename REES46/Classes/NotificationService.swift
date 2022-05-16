//
//  NotificationService.swift
//  REES46
//
//  Created by Arseniy Dorogin on 26.03.2022.
//

import Foundation
import UserNotifications

public protocol NotificationServicePushDelegate: AnyObject {
    func openCategory(categoryId: String)
    func openProduct(productId: String)
    func openWeb(url: String)
    func openCustom(url: String)
}

public protocol NotificationServiceProtocol {
    func didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data)
    func didReceiveRemoteNotifications(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult, String) -> Void)
    func didReceiveRegistrationFCMToken(fcmToken: String?)
    func didReceiveDeepLink(url: URL)
    
    var pushActionDelegate: NotificationServicePushDelegate? { get set }
}

public class NotificationService: NotificationServiceProtocol {
    
    public var pushActionDelegate: NotificationServicePushDelegate?
    
    public let sdk: PersonalizationSDK
    
    public init(sdk: PersonalizationSDK) {
        self.sdk = sdk
        requiereUserPrivacy { res in
            if res {
                if #available(iOS 10.0, *) {
                    let categoryIdentifier = "carousel"
                    let carouselNext = UNNotificationAction(identifier: "carousel.next", title: "Следующий", options: [])
                    let carouselPrevious = UNNotificationAction(identifier: "carousel.previous", title: "Предыдущий", options: [])

                    let carouselCategory = UNNotificationCategory(identifier: categoryIdentifier, actions: [carouselNext, carouselPrevious], intentIdentifiers: [], options: [])
                    UNUserNotificationCenter.current().setNotificationCategories([carouselCategory])
                }
            }
        }
    }

    public func didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            String(format: "%02.2hhx", data)
        }

        let token = tokenParts.joined()
        sdk.setPushTokenNotification(token: token) { tokenResponse in
            switch tokenResponse {
            case .success():
                return
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
            }
        }
    }

    public func didReceiveRemoteNotifications(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult, String) -> Void) {
        if application.applicationState == .active {
            // SKIP FOR NOW
        } else if application.applicationState == .background || application.applicationState == .inactive {
            pushProcessing(userInfo: userInfo)
        }
    }
    
    public func didReceiveRegistrationFCMToken(fcmToken: String?) {
        print("Firebase fcm token = \(fcmToken)")
        sdk.setFirebasePushToken(token: fcmToken ?? "") { tokenResponse in
            switch tokenResponse {
            case .success():
                return
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
            }
        }
    }
    
    public func didReceiveDeepLink(url: URL) {
        let urlString = url.absoluteString
        let splitedUrlString = urlString.split(separator: "/")
        for path in splitedUrlString {
            let stringPath = String(path)
            switch PushEventType.findType(value: stringPath) {
            case .product:
                openProduct(productId: url.lastPathComponent)
            case .category:
                openCategory(categoryId: url.lastPathComponent)
            default:
                continue
            }
        }
    }
    
    private func requiereUserPrivacy(completion: @escaping (Bool) -> Void) {
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
            UIApplication.shared.registerForRemoteNotifications()
            let options: UNAuthorizationOptions = [.alert]
            UNUserNotificationCenter.current().requestAuthorization(options: options) { authorized, _ in
                completion(authorized)
            }
        }
    }
    
    private func pushProcessing(userInfo: [AnyHashable: Any]) {
        print(userInfo)
        guard let eventJSON = parseDictionary(key: "event", userInfo: userInfo) else {
            guard let basicPush = parseDictionary(key: "aps", userInfo: userInfo) else {
                processingNotSDKPush(userInfo: userInfo)
                return
            }
            if let type = userInfo["type"] as? String {
                if let id = userInfo["id"] as? String {
                    notificationClicked(type: type, code: id)
                    return
                }
            }
            guard let src = parseDictionary(key: "src", userInfo: userInfo) else {
                processingNotSDKPush(userInfo: userInfo)
                return
            }
            
            if let type = src["type"] as? String {
                if let id = src["id"] as? String {
                    notificationClicked(type: type, code: id)
                    return
                }
            }
            return
        }
        
        guard let eventType = eventJSON["type"] as? String else {
            processingNotSDKPush(userInfo: userInfo)
            return
        }
        var src: [String: Any] = [:]
        if let srcFromUserInfo = parseDictionary(key: "src", userInfo: userInfo) {
            src = srcFromUserInfo
        } else {
            if let srcID = userInfo["id"] as? String {
                src["id"] = srcID
            }
        }
        
        guard let srcID = src["id"] as? String else {
            processingNotSDKPush(userInfo: userInfo)
            return
        }
        
        notificationClicked(type: eventType, code: srcID)
        
        if eventType != PushEventType.carousel.rawValue {
            guard var eventLink = eventJSON["uri"] as? String else {
                processingNotSDKPush(userInfo: userInfo)
                return
            }
            if eventLink.contains("https://") {
                eventLink += "?recommended_by=\(eventType)&mail_code=\(srcID)"
            }
            processingEventType(eventType: eventType, eventLink: eventLink)
        }
        
        
    }
    
    private func notificationClicked(type: String, code: String) {
        sdk.notificationClicked(type: type, code: code) { _ in
            self.sdk.track(event: .productView(id: "17520")) { _ in
                
            }
        }
    }
    
    private func processingEventType(eventType: String, eventLink: String) {
        switch PushEventType.findType(value: eventType) {
        case .web:
            openWeb(url: eventLink)
        case .product:
            openProduct(productId: eventLink)
        case .category:
            openCategory(categoryId: eventLink)
        case .carousel:
            break
        default:
            openCustom(url: eventLink)
        }
    }

    private func parseDictionary(key: String, userInfo: [AnyHashable: Any]) -> [String: Any]? {
        let eventUserInfo = userInfo[key]
        if let eventJSONString = eventUserInfo as? String {
            if let data = eventJSONString.data(using: .utf8) {
                let json = try? JSONSerialization.jsonObject(with: data)
                if let jsonObject = json as? [String: Any] {
                    return jsonObject
                }
            }
        }
        if let eventJSONDict = eventUserInfo as? [String: Any] {
            return eventJSONDict
        }
        return nil
    }
    
    private func processingNotSDKPush(userInfo: [AnyHashable: Any]) {
        print("Push data = \(userInfo)")
    }
    
    private func processingUnknownLink() {
        print("Unknown url link")
    }

    private func openCategory(categoryId: String) {
        pushActionDelegate?.openCategory(categoryId: categoryId)
    }

    private func openProduct(productId: String) {
        pushActionDelegate?.openProduct(productId: productId)
    }

    private func openWeb(url: String) {
        pushActionDelegate?.openWeb(url: url)
    }
        
    private func openCustom(url: String) {
        pushActionDelegate?.openCustom(url: url)
    }
}
