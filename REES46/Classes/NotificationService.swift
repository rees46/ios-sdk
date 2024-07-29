//
//  NotificationService.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation
import UserNotifications
import UIKit

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
    private let notificationRegistrar: NotificationRegistrar
    
    public init(sdk: PersonalizationSDK) {
        self.sdk = sdk
        self.notificationRegistrar = NotificationRegistrar(sdk: sdk)
        setupNotificationCategories()
    }
    
    public func didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data) {
        notificationRegistrar.registerWithDeviceToken(deviceToken: deviceToken)
    }
    
    private func setupNotificationCategories() {
        requireUserPrivacy { res in
            if res {
                let categoryIdentifier = "carousel"
                let carouselNext = UNNotificationAction(identifier: "carousel.next", title: "Next", options: [])
                let carouselPrevious = UNNotificationAction(identifier: "carousel.previous", title: "Previous", options: [])
                let carouselCategory = UNNotificationCategory(identifier: categoryIdentifier, actions: [carouselNext, carouselPrevious], intentIdentifiers: [], options: [])
                UNUserNotificationCenter.current().setNotificationCategories([carouselCategory])
            }
        }
    }
    
    public func didReceiveRemoteNotifications(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult, String) -> Void) {
        if application.applicationState == .active {
            // SKIP FOR NOW
        } else if application.applicationState == .background {
            pushRetrieved(userInfo: userInfo)
        } else if application.applicationState == .inactive {
            pushProcessing(userInfo: userInfo)
        }
    }
    
    public func didReceiveRegistrationFCMToken(fcmToken: String?) {
        sdk.setPushTokenNotification(token: fcmToken ?? "", isFirebaseNotification: true) { tokenResponse in
            switch tokenResponse {
            case .success():
                return
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error:", customError)
                default:
                    print("Error:", error.description)
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
    
    private func requireUserPrivacy(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
        UIApplication.shared.registerForRemoteNotifications()
        let options: UNAuthorizationOptions = [.alert]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { authorized, _ in
            completion(authorized)
        }
    }
    
    private func pushProcessing(userInfo: [AnyHashable: Any]) {
        guard let eventJSON = parseDictionary(key: "event", userInfo: userInfo) else {
            guard parseDictionary(key: "aps", userInfo: userInfo) != nil else {
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
    
    private func pushRetrieved(userInfo: [AnyHashable: Any]) {
        guard let (type, code) = extractTypeAndCode(from: userInfo) else {
            processingNotSDKPush(userInfo: userInfo)
            return
        }
        
        notificationReceived(type: type, code: code)
        
        guard let eventJSON = parseDictionary(key: "event", userInfo: userInfo),
              let eventType = eventJSON["type"] as? String else {
            processingNotSDKPush(userInfo: userInfo)
            return
        }
        
        guard var eventLink = eventJSON["uri"] as? String else {
            processingNotSDKPush(userInfo: userInfo)
            return
        }
        
        if eventLink.contains("https://") {
            eventLink += "?recommended_by=\(eventType)&mail_code=\(code)"
        }
        
        processingEventType(eventType: eventType, eventLink: eventLink)
    }

    private func extractTypeAndCode(from userInfo: [AnyHashable: Any]) -> (type: String, code: String)? {
        if let eventJSON = parseDictionary(key: "event", userInfo: userInfo),
           let eventType = eventJSON["type"] as? String,
           let src = parseDictionary(key: "src", userInfo: userInfo) ?? (userInfo["id"].map { ["id": $0] } as? [String: Any]),
           let srcID = src["id"] as? String {
            return (eventType, srcID)
        }
        
        if let type = userInfo["type"] as? String,
           let id = userInfo["id"] as? String {
            return (type, id)
        }
        
        if let src = parseDictionary(key: "src", userInfo: userInfo),
           let type = src["type"] as? String,
           let id = src["id"] as? String {
            return (type, id)
        }
        
        return nil
    }
    
    private func notificationDelivered(type: String, code: String) {
        sdk.notificationDelivered(type: type, code: code) { error in
            print("Error caught in notificationDelivered: \(error)")
        }
    }
    
    private func notificationClicked(type: String, code: String) {
        sdk.notificationClicked(type: type, code: code) { error in
            print("Error caught in notificationReceived: \(error)")
        }
    }
    
    private func notificationReceived(type: String, code: String) {
        sdk.notificationReceived(type: type, code: code) { error in
            print("Error caught in notificationReceived: \(error)")
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
