# REES46 iOS SDK

[![CI Status](https://img.shields.io/travis/Avsi222/REES46.svg?style=flat)](https://travis-ci.org/Avsi222/REES46)
[![Version](https://img.shields.io/cocoapods/v/REES46.svg?style=flat)](https://cocoapods.org/pods/REES46)
[![License](https://img.shields.io/cocoapods/l/REES46.svg?style=flat)](https://cocoapods.org/pods/REES46)
[![Platform](https://img.shields.io/cocoapods/p/REES46.svg?style=flat)](https://cocoapods.org/pods/REES46)

![REES46](https://rees46.com/static-images/cocoapods/r46_ios_sdk_cocoapods_cover.png)

## Installation

REES46 SDK is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'REES46'
```

## Swift Package Manager

If you are using Xcode 11 or later:
1. Click `File`
2. `Swift Packages`
3. `Add Package Dependency...`
4. Specify the git URL for REES46 SDK repo.

```ruby
https://github.com/rees46/ios-sdk.git
```

# Usage

SDK is used for several tasks:

1. Initialize SDK and user's session
2. Events tracking
3. Product recommendations
4. Product search
5. Populate user's profile with new data
6. Send mobile push token
7. Utilities

## Initialization

Initialize SDK object and use it anywhere in your application. (!) Remember to initialize SDK only once on application launch.

```swift
import REES46
.....
var sdk = createPersonalizationSDK(shopId: "API_KEY")
```

Or with completion to handle problems:

```swift
import REES46
.....
sdk = createPersonalizationSDK(shopId: "API_KEY", { (error) in
    print(error)
})
```

## Events tracking

Track user's behavior to collect data. There are several types of events:

### User viewed a product

```swift
// Common view
sdk.track(event: .productView(id: "PRODUCT_ID")) { _ in
  print("Product view callback")
}

// From instant search
sdk.track(event: .productView(id: "PRODUCT_ID"), recommendedBy: 'instant_search') { _ in
  print("Product view callback")
}

// From full search
sdk.track(event: .productView(id: "PRODUCT_ID"), recommendedBy: 'full_search') { _ in
  print("Product view callback")
}

// From recommender block - use block ID for recommendedBy parameter
sdk.track(event: .productView(id: "PRODUCT_ID"), recommendedBy: 'WTJc23B2pTBsgc0e') { _ in
  print("Product view callback")
}
```

### User viewed a category

```swift
sdk.track(event: .categoryView(id: "CATEGORY_ID")) { _ in
  print("Category view callback")
}
```

### User added a product to wish list

```swift
sdk.track(event: .productAddedToFavorities(id: "PRODUCT_ID")) { _ in
  print("Product is added to wish list callback")
}
```

### User removed a product from wish list

```swift
sdk.track(event: .productRemovedToFavorities(id: "PRODUCT_ID")) { _ in
  print("Product is removed from wish list callback")
}
```

### User added a product to shopping cart

```swift
sdk.track(event: .productAddedToCart(id: "PRODUCT_ID")) { _ in
  print("Product is added to cart callback")
}
```

> Also supports `recommendedBy` parameter

### User removed a product from shopping cart

```swift
sdk.track(event: .productRemovedFromCart(id: "PRODUCT_ID")) { _ in
  print("Product is removed from cart callback")
}
```

### Synchronize shopping cart

This method is used to override current state of user's shopping cart. It's easier to sync cart with API using this method, than `productAddedToCart` and `productRemovedFromCart` methods.

```swift
sdk.track(event: .synchronizeCart(ids: ["PRODUCT_1_ID", "PRODUCT_2_ID"])) { _ in
  print("Cart is synced callback")
}
```

### User is made a purchase

```swift
sdk.track(event: .orderCreated(orderId: "ORDER_ID", totalValue: 33.3, products: [(id: "PRODUCT_1_ID", amount: 3), (id: "PRODUCT_2_ID", amount: 1)])) { _ in
  print("Order is created callback")
}
```

## Product recommendations

You can use recommender engine in two ways:

1. Simple block request
2. Request with additional data

### Simple request

```swift
sdk.recommend(blockId: "BLOCK_ID") { recommendResult in
  print("Callback")
}
```

### Request with additional data

For example, you can provide current product ID (to exclude it from recommended products when user sees this product's details page):

```swift
sdk.recommend(blockId: "block_id", currentProductId: "PRODUCT_ID") { recommendResult in
  print("Callback")
}
```

## Product search

We have 2 types of search:

1. Suggest (or typeahead)
2. Full search

### Suggest

```swift
sdk.suggest(query: "ipho") { searchResult in
  print("Suggest callback")
}
```

### Full search

Full search can be performed as simple query and query with filter parameters.

Simple full search:

```swift
sdk.search(query: "iphone") { searchResult in
  print("Full search callback")
}
```

Full search with additional filters:

```swift
sdk.search(query: "laptop", limit: nil, offset: nil, categoryLimit: nil, categories: nil, extended: nil, sortBy: nil, sortDir: nil, locations: nil, brands: nil, filters: nil, priceMin: nil, priceMax: nil, colors: nil, exclude: nil) { searchResult in
  print("Full search callback")
}
```

Parameters list:

Parameter | Required | Description
--------- | ------- | -----------
query | true | Search query
limit | false | Limit of results
offset | false | Offset of results
categoryLimit | false | How many categories for sidebar filter to return
categories | false | Dictionary categories list to filter products by
extended | false | It's better to use `true` for full search results
sortBy | false | Sort by parameter: `popular`, `price`, `discount`
sortDir | false | Sort direction: `asc` or `desc` (default)
locations | false | Dictionary list of locations IDs
brands | false | Dictionary list of brands to filter
filters | false | JSON object with filter parameters. For example: ["bluetooth":["yes"],"offers":["15% cashback"],"weight":["1.6"]]
priceMin | false | Min price
priceMax | false | Max price
colors | false | Dictionary list of colors
exclude | false | Dictionary list of products IDs to exclude from search results

Output:

```swift
categories = [Category];
products =  [Product];
productsTotal =  Int;
queries = [Query];
```

## Populate user's profile with new data

You can populate user's profile with additional data.

For example, save email to user's profile:

```swift
sdk.setProfileData(userEmail: "EMAIL@EXAMPLE.COM") { (profileDataResp) in
    print("Profile data callback")
 }
```

Or you can provide more data:

```swift
sdk.setProfileData(userEmail: "EMAIL@EXAMPLE.COM", userPhone: "+111111111111", userLoyaltyId: "LOYALTY_CARD_ID", birthday: nil, age: nil, firstName: "Johny", secondName: nil, lastName: "Cash", location: nil, gender: .male) { (profileDataResp) in
  print("Profile data callback")
 }
```


## Send mobile push token

```swift
sdk.setPushTokenNotification(token: "TOKEN_STRING") { (tokenResponse) in
  print("Token set response")
}
```

## Save review

```swift
sdk.review(rate: 5, channel: "ios_app", category: "delivery", comment: "Nice application, thank you!") { (reviewResponse) in
  print("Review is saved")
}
```

Parameters list:

Parameter | Required | Description
--------- | ------- | -----------
rate | true | Score of the rated process. Value between 1 - 10
channel | true | NPS channel code
category | true | NPS process category code
comment | false | Optional answer to the follow-up question
orderId | false | Order ID, related to the current survey

# Push Notifications
## Setup push service
### Step 1 - Add a Notification Service Extension
The REESNotificationServiceExtension allows your iOS application to receive rich notifications with images, buttons, and badges. It's also required for OneSignal's analytics features.

1.1 In Xcode Select File > New > Target...
1.2 Select Notification Service Extension then press Next.
1.3 Enter the product name as REESNotificationServiceExtension and press Finish.
    Do not select Activate on the dialog that is shown after selecting Finish.
1.4 Press Cancel on the Activate scheme prompt.
1.5 In the project navigator, click the REESNotificationServiceExtension folder and open the NotificationService.swift and replace the whole file's contents with the following code.


```swift
import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var receivedRequest: UNNotificationRequest!
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.receivedRequest = request;
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
3.3 If you do not see Push Notifications enabled, click "+ Capability" and double click "Push Notifications" to add it.

## Carousel Push SDK
### Step 1. Add a Notification Content Extension

1) In Xcode, select File > New > Target...
2) Select the Notification Content Extension
3) Name it REESNotificationContentExtension
4) Select Activate to debug the new scheme.

### Step 2. Add Code to your App
Download the REESNotificationContentExtension from Github and replace the REESNotificationContentExtension in your Xcode Project with the same file from Github.

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
        let carouselNext = UNNotificationAction(identifier: "carousel.next", title: "След", options: [])
        let carouselPrevious = UNNotificationAction(identifier: "carousel.previous", title: "Пред", options: [])

        let carouselCategory = UNNotificationCategory(identifier: categoryIdentifier, actions: [carouselNext, carouselPrevious], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([carouselCategory])
    }
}

```

## Utilities

These method are used for debug tasks. You don't need it for common tasks.

### Get session ID

```swift
let deviceID = sdk.getDeviceID()
```

## Author

REES46, desk@rees46.com

## License

REES46 SDK is available under the MIT license. See the LICENSE file for more info.
