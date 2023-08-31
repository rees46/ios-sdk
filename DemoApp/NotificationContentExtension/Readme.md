# Push Notifications
## Setup push service
### Step 1 - Add a Notification Service Extension
The NotificationServiceExtension allows your iOS application to receive rich notifications with images, buttons, and badges. 

1.1 In Xcode Select File > New > Target...

1.2 Select Notification Service Extension then press Next.

1.3 Enter the product name as NotificationServiceExtension and press Finish.
Do not select Activate on the dialog that is shown after selecting Finish.

1.4 Press Cancel on the Activate scheme prompt.

1.5 In the project navigator, click the NotificationServiceExtension folder and open the NotificationService.swift and replace the whole file's contents with the following code.


```swift
import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var receivedRequest: UNNotificationRequest!
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.receivedRequest = request
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
```
### Step 2 - Add Required Capabilities

This step will make sure your project is able to receive remote notifications,

Only do this for the main application target.
Do not do this for the Notification Service Extension.

2.1 Select the root project, your main app target and "Signing & Capabilities"

2.2 Select "All", then under "Background Modes" check "Remote notifications". You should see Push Notifications already provided.

2.3 If you do not see Push Notifications enabled, click "+ Capability" and double click "Push Notifications" to add it.

## Carousel Push SDK
### Step 1. Add a Notification Content Extension

1) In Xcode, select File > New > Target...
2) Select the Notification Content Extension
3) Name it NotificationContentExtension
4) Select Activate to debug the new scheme.

### Step 2. Add Code to your App
Download the NotificationContentExtension from Github and replace the NotificationContentExtension in your Xcode Project with the same file from Github.

### Step 3. Set Your Notification Category
In the AppDelegate.swift didFinishLaunchingWithOptions add the following code for activate push and end carousel setup :


```swift

let center = UNUserNotificationCenter.current()
center.requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
UIApplication.shared.registerForRemoteNotifications()
let options: UNAuthorizationOptions = [.alert]
UNUserNotificationCenter.current().requestAuthorization(options: options) { authorized, _ in
    if authorized {
        let categoryIdentifier = "carousel"
        let carouselNext = UNNotificationAction(identifier: "carousel.next", title: "Next", options: [])
        let carouselPrevious = UNNotificationAction(identifier: "carousel.previous", title: "Previous", options: [])

        let carouselCategory = UNNotificationCategory(identifier: categoryIdentifier, actions: [carouselNext, carouselPrevious], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([carouselCategory])
    }
}

```
