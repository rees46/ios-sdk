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
    static let typeKey: String = "type"
    static let uriKey: String = "uri"
    static let urlScheme: String = "https://"
    static let idKey: String = "id"
    static let srcKey: String = "src"
  }
  
  public var pushActionDelegate: NotificationActionsProtocol?

  /// Retained for source compatibility. Notification tracking now routes through `Rees46.handlePush`
  /// (which resolves the shop by `shop_id`), so this service no longer drives the delegate — a delegate
  /// that called back into a single captured `sdk` would mis-track in a multi-shop app and double-track
  /// alongside `handlePush`. `NotificationTracker` still constructs but is inert.
  public var notificationTrackerDelegate: NotificationTrackerDelegate?
  
  public let sdk: PersonalizationSDK
  private let notificationRegistrar: NotificationRegistrar
  private let notificationLogger: NotificationLogger
  
  public init(sdk: PersonalizationSDK, notificationLogger: NotificationLogger) {
    self.sdk = sdk
    self.notificationLogger = notificationLogger
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
  
  public func didReceiveRemoteNotifications(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult, String) -> Void
  ) {
    
    // Track against the shop the push names (multi-instance): `Rees46.handlePush` resolves the target
    // by `shop_id` instead of the single sdk captured at init, which would otherwise mis-track in a
    // multi-shop app. Navigation below stays with this service / the host.
    Rees46.handlePush(userInfo, event: .delivered)

    handleArrival(userInfo, state: application.applicationState)
    completionHandler(.newData, "CompletionHandler")
  }

  /// What the arrival of a push means in each app state. `.inactive` is the tap that brings the app
  /// back; `.active` is a push that came while the app is open: nobody tapped it, so it is not a click
  /// and opens nothing.
  func handleArrival(_ userInfo: [AnyHashable: Any], state: UIApplication.State) {
    switch state {
    case .active:
      notificationLogger.log("Application is in active state: the push arrived, nobody tapped it")
    case .background:
      notificationLogger.log("Application is in background state")
      pushRetrieved(userInfo: userInfo)
    case .inactive:
      notificationLogger.log("Application is in inactive state")
      pushProcessing(userInfo: userInfo)
    @unknown default:
      notificationLogger.log("Application is in an unknown state")
    }
  }
  
  
  
  public func didReceiveRegistrationFCMToken(fcmToken: String?) {
    notificationLogger.log("didReceiveRegistrationFCMToken with token: \(String(describing: fcmToken))")
    
    sdk.setPushTokenNotification(token: fcmToken ?? "", isFirebaseNotification: true) { tokenResponse in
      switch tokenResponse {
      case .success():
        self.notificationLogger.log("Successfully registered FCM token")
      case let .failure(error):
        self.notificationLogger.log("Error: \(error)")
      }
    }
  }
  
  public func didReceiveDeepLink(url: URL) {
    notificationLogger.log("didReceiveDeepLink with url: \(url)")
    
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
    notificationLogger.log("pushProcessing with userInfo: \(userInfo)")
    
    guard let (mailingType, code) = extractTypeAndCode(from: userInfo) else {
      notificationLogger.log("Failed to extract type and code, skipping processing")
      handleNonSDKPush(userInfo: userInfo)
      return
    }

    Rees46.handlePush(userInfo, event: .clicked)

    // What to open is the event's type (web, product, …); the link carries the mailing's type.
    if let eventJSON = PushPayloadParser.event(from: userInfo),
       let eventLink = eventJSON[Constants.uriKey] as? String {
      var modifiedEventLink = eventLink
      if modifiedEventLink.contains(Constants.urlScheme) {
        modifiedEventLink += "?recommended_by=\(mailingType)&mail_code=\(code)"
      }
      processingEventType(eventType: eventJSON[Constants.typeKey] as? String ?? "", eventLink: modifiedEventLink)
    } else {
      notificationLogger.log("Event link not found or invalid")
    }
  }
  
  
  private func pushRetrieved(userInfo: [AnyHashable: Any]) {
    notificationLogger.log("pushRetrieved with userInfo: \(userInfo)")
    
    guard let (mailingType, code) = extractTypeAndCode(from: userInfo) else {
      handleNonSDKPush(userInfo: userInfo)
      return
    }

    Rees46.handlePush(userInfo, event: .received)
    
    guard let eventJSON = PushPayloadParser.event(from: userInfo),
          let eventType = eventJSON[Constants.typeKey] as? String,
          let eventLink = eventJSON[Constants.uriKey] as? String else {
      handleNonSDKPush(userInfo: userInfo)
      return
    }
    
    var modifiedEventLink = eventLink
    if modifiedEventLink.contains(Constants.urlScheme) {
      modifiedEventLink += "?recommended_by=\(mailingType)&mail_code=\(code)"
    }
    
    processingEventType(eventType: eventType, eventLink: modifiedEventLink)
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
  
  public func extractTypeAndCode(from userInfo: [AnyHashable: Any]) -> (type: String, code: String)? {
    // Shared with `Rees46.handlePush` so both paths accept the same payload shapes.
    PushPayloadParser.typeAndCode(from: userInfo)
  }
  
  /// A field that is a JSON object: an object in APNs, a JSON string in FCM.
  public func parseDictionary(key: String, userInfo: [AnyHashable: Any]) -> [String: Any]? {
      PushPayloadParser.dictionary(for: key, in: userInfo)
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
    notificationLogger.log("Non-SDK push received with data: \(userInfo)")
  }
}
