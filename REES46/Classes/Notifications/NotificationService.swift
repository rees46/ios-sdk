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

public class NotificationService: NotificationServiceProtocol {
    
    struct Constants {
        static let actionsKey: String = "ACTIONS_IS_RUNNING"
        static let carouselKey: String = "carousel"
        static let carouselButtonNext: String = "carousel.next"
        static let buttonNextKey: String = "carousel_button_next"
        static let carouselButtonPrevious: String = "carousel.previous"
        static let buttonPreviousKey: String = "carousel_button_previous"
        static let eventKey: String = "event"
        static let titleKey: String = "title"
        static let bodyKey: String = "body"
        static let idKey: String = "id"
        static let typeKey: String = "type"
        static let srcKey: String = "src"
        static let uriKey: String = "uri"
        static let urlScheme: String = "https://"
    }
    
    public var pushActionDelegate: NotificationActionsProtocol?
    
    public let sdk: PersonalizationSDK
    private let notificationRegistrar: NotificationRegistrar
    private let logTag = "PUSH"
    
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
                let carouselNext = UNNotificationAction(
                    identifier: Constants.carouselButtonNext,
                    title: NSLocalizedString(Constants.buttonNextKey, comment: ""),
                    options: []
                )
                let carouselPrevious = UNNotificationAction(
                    identifier: Constants.carouselButtonPrevious,
                    title: NSLocalizedString(Constants.buttonPreviousKey, comment: ""),
                    options: []
                )
                let carouselCategory = UNNotificationCategory(
                    identifier: Constants.carouselKey,
                    actions: [carouselNext, carouselPrevious],
                    intentIdentifiers: [],
                    options: []
                )
                UNUserNotificationCenter.current().setNotificationCategories([carouselCategory])
            }
        }
    }
    
    public func didReceiveRemoteNotifications(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult, String) -> Void) {
        
        notificationDelivered(userInfo: userInfo)
        
        switch application.applicationState {
        case .active:
            log("Application is in active state, displaying notification")
        case .background:
            log("Application is in background state")
            pushRetrieved(userInfo: userInfo)
        case .inactive:
            log("Application is in inactive state")
            pushProcessing(userInfo: userInfo)
        @unknown default:
            log("Application is in an unknown state")
        }
        completionHandler(.newData, "CompletionHandler")
    }
    
    public func didReceiveRegistrationFCMToken(fcmToken: String?) {
        log("didReceiveRegistrationFCMToken with token: \(String(describing: fcmToken))")
        
        sdk.setPushTokenNotification(token: fcmToken ?? "", isFirebaseNotification: true) { tokenResponse in
            switch tokenResponse {
            case .success():
                self.log("Successfully registered FCM token")
            case let .failure(error):
                self.log("Error: \(error)")
            }
        }
    }
    
    public func didReceiveDeepLink(url: URL) {
        log("didReceiveDeepLink with url: \(url)")
        
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
        center.requestAuthorization(options: [.badge, .alert, .sound]) { granted, error in
            if let error = error {
                print("Request authorization error: \(error)")
            }
            print("User authorization granted: \(granted)")
            completion(granted)
        }
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    private func pushProcessing(userInfo: [AnyHashable: Any]) {
        log("pushProcessing with userInfo: \(userInfo)")
        
        guard let (eventType, srcID) = extractTypeAndCode(from: userInfo) else {
            handleNonSDKPush(userInfo: userInfo)
            return
        }
        
        notificationClicked(type: eventType, code: srcID)
        
        if eventType != PushEventType.carousel.rawValue, var eventLink = (
            parseDictionary(key: Constants.eventKey, userInfo: userInfo)?[Constants.uriKey] as? String
        ) {
            if eventLink.contains(Constants.urlScheme) {
                eventLink += "?recommended_by=\(eventType)&mail_code=\(srcID)"
            }
            processingEventType(eventType: eventType, eventLink: eventLink)
        }
    }
    
    private func pushRetrieved(userInfo: [AnyHashable: Any]) {
        log("pushRetrieved with userInfo: \(userInfo)")
        
        guard let (type, code) = extractTypeAndCode(from: userInfo) else {
            handleNonSDKPush(userInfo: userInfo)
            return
        }
        
        notificationReceived(type: type, code: code)
        
        guard let eventJSON = parseDictionary(key: Constants.eventKey, userInfo: userInfo),
              let eventType = eventJSON[Constants.typeKey] as? String,
              var eventLink = eventJSON[Constants.uriKey] as? String else {
            handleNonSDKPush(userInfo: userInfo)
            return
        }
        
        if eventLink.contains(Constants.urlScheme) {
            eventLink += "?recommended_by=\(eventType)&mail_code=\(code)"
        }
        
        processingEventType(eventType: eventType, eventLink: eventLink)
    }
    
    private func notificationDelivered(userInfo: [AnyHashable: Any]) {
        guard let (eventType, srcID) = extractTypeAndCode(from: userInfo) else {
            handleNonSDKPush(userInfo: userInfo)
            return
        }
        sdk.notificationDelivered(type: eventType, code: srcID) { error in
            self.log("NotificationDelivered: \(error)")
        }
    }
    
    private func notificationClicked(type: String, code: String) {
        sdk.notificationClicked(type: type, code: code) { error in
            self.log("NotificationClicked: \(error)")
        }
    }
    
    private func notificationReceived(type: String, code: String) {
        sdk.notificationReceived(type: type, code: code) { error in
            self.log("NotificationReceived: \(error)")
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
    
    private func extractTypeAndCode(from userInfo: [AnyHashable: Any]) -> (type: String, code: String)? {
        if let eventJSON = parseDictionary(key: Constants.eventKey, userInfo: userInfo),
           let eventType = eventJSON[Constants.typeKey] as? String,
           let src = parseDictionary(key: Constants.srcKey, userInfo: userInfo) ?? (userInfo[Constants.idKey].map {
               [Constants.idKey: $0]
           } as? [String: Any]),
           let srcID = src[Constants.idKey] as? String {
            return (eventType, srcID)
        }
        
        if let type = userInfo[Constants.typeKey] as? String, let id = userInfo[Constants.idKey] as? String {
            return (type, id)
        }
        
        if let src = parseDictionary(key: Constants.srcKey, userInfo: userInfo),
           let type = src[Constants.typeKey] as? String, let id = src[Constants.idKey] as? String {
            return (type, id)
        }
        
        return nil
    }
    
    private func parseDictionary(key: String, userInfo: [AnyHashable: Any]) -> [String: Any]? {
        if let eventJSONString = userInfo[key] as? String,
           let data = eventJSONString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let jsonDict = jsonObject as? [String: Any] {
            return jsonDict
        }
        
        return userInfo[key] as? [String: Any]
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
    
    private func handleNonSDKPush(userInfo: [AnyHashable: Any]) {
        log("Non-SDK push received with data: \(userInfo)")
    }
    
    private func log(_ message: String) {
        print("\(logTag): \(message)")
    }
}
