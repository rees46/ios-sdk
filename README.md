# REES46

[![CI Status](https://img.shields.io/travis/Avsi222/REES46.svg?style=flat)](https://travis-ci.org/Avsi222/REES46)
[![Version](https://img.shields.io/cocoapods/v/REES46.svg?style=flat)](https://cocoapods.org/pods/REES46)
[![License](https://img.shields.io/cocoapods/l/REES46.svg?style=flat)](https://cocoapods.org/pods/REES46)
[![Platform](https://img.shields.io/cocoapods/p/REES46.svg?style=flat)](https://cocoapods.org/pods/REES46)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

REES46 is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'REES46'
```

## Swift Package Manager

If you are using Xcode 11 or later:
1. Click `File`
2. `Swift Packages`
3. `Add Package Dependency...`
4. Specify the git URL for REES46.

```swift
https://github.com/rees46/ios-sdk.git
```

# Usage
## Initialization

```swift

import REES46

.....
var sdk = createPersonalizationSDK(shopId: "API_KEY")
```

## Get session id

```swift
let ssid = sdk.getSSID()
```

## Send token for push notification
Send token for push notifications.

```swift
sdk.setPushTokenNotification(token: "testToken") { (tokenResponse) in
    print("     Token set response")
}
```

## Track
Send track event to server.
The track method has next events:

1) Product view

```swift
sdk.track(event: .productView(id: "123")) { _ in
      print("   Product view callback")
}
```

2) Category View 

```swift
sdk.track(event: .categoryView(id: "123")) { _ in
            print("   Category view callback")
}
```

3) Product add to favorites

```swift
sdk.track(event: .productAddedToFavorities(id: "123")) { _ in
            print("   Product added to favorities callback")
}
```

4) Product remove from Favorites

```swift
sdk.track(event: .productRemovedToFavorities(id: "123")) { _ in
            print("   Product removed from favorities callback")
}
```

5) Product add to Cart

```swift
sdk.track(event: .productAddedToCart(id: "123")) { _ in
    print("   Product added to cart callback")
}
```

6) Product remove from cart

```swift
sdk.track(event: .productRemovedFromCart(id: "123")) { _ in
    print("   Product removed from cart callback")
}
```

7) Syncronize cart

```swift
sdk.track(event: .syncronizeCart(ids: ["1", "2"])) { _ in
    print("   Cart syncronized callback")
}
```

8) Create Order

```swift
sdk.track(event: .orderCreated(orderId: "123", totalValue: 33.3, products: [(id: "1", amount: 3), (id: "2", amount: 1)])) { _ in
    print("   Order created callback")
}
```

## Recommend
Get recommends product ids.
```swift
sdk.recommend(blockId: "block_id") { recomendResult in
    print("   Recommendations requested callback")
}
```

Or

```swift
sdk.recommend(blockId: "block_id", currentProductId: "1") { recomendResult in
    print("   Recommendations requested callback")
}
```

Output:

recomended = [Sting] - products ids array; 
title = String - title block recomend

## Search
Get search response for qeury in two statament ( partial search and full search)

Partial search: 

```swift
sdk.search(query: "iphone", searchType: .instant) { searchResult in
    print("   Instant search callback")
}
```

Full search: 

```swift
sdk.search(query: "iphone", searchType: .full) { searchResult in
    print("   Full search callback")
}
```

Output:

categories = [Category]; 
products =  [Product]; 
productsTotal =  Int; 
queries = [Query] .

## Set user data
Send user data

```swift
sdk.setProfileData(userEmail: "email") { (profileDataResp) in
      print("     Profile data callback")
 }
```

Or 

```swift
sdk.setProfileData(userEmail: "email", userPhone: "123", userLoyaltyId: "1", birthday: nil, age: nil, firstName: "Ars", secondName: "test", lastName: nil, location: nil, gender: .male) { (profileDataResp) in
      print("     Profile data callback")
 }
```


## Author

Avsi222, «dorogin.arseniy@yandex.ru»

## License

REES46 is available under the MIT license. See the LICENSE file for more info.
