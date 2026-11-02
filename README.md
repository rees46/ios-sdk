# REES46 SDK for iOS

![REES46](https://github.com/user-attachments/assets/f84f80c5-5884-42f5-92d5-65f2a4c30aee)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)
[![Version](https://img.shields.io/github/v/release/rees46/ios-sdk?style=for-the-badge)](https://github.com/rees46/ios-sdk/releases/latest)
![Swift](https://img.shields.io/badge/swift-5-F54A2A?style=for-the-badge&logo=swift&logoColor=white&labelColor=F54A2A)
![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-F54A2A?style=for-the-badge&logo=swift&logoColor=white)
[![License](https://img.shields.io/github/license/rees46/ios-sdk?style=for-the-badge)](LICENSE)

## Description

REES46 SDK for iOS platform - the wide toolset for eCommerce apps.
This SDK can be used to integrate in your own app for iOS in few steps.

## Installation

The SDK supports iOS 12.0 and later.

### Swift Package Manager

In Xcode choose **File → Add Package Dependencies…**, enter
`https://github.com/rees46/ios-sdk.git` and add the `REES46` library to your app target.

In a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rees46/ios-sdk.git", from: "3.36.0")
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "REES46", package: "ios-sdk")
    ])
]
```

### CocoaPods

CocoaPods trunk is read-only from 2 December 2026, so new versions of the SDK are no
longer published there; 3.36.0 is the last one. To stay on CocoaPods, take the pod
straight from this repository, with the tag of the [release](https://github.com/rees46/ios-sdk/releases)
you need:

```ruby
pod 'REES46', :git => 'https://github.com/rees46/ios-sdk.git', :tag => 'v3.36.0'
```

Moving from CocoaPods to Swift Package Manager keeps the device identity: the SDK picks
up what the CocoaPods build stored in the keychain.

## Documentation

For detailed information on methods, please refer to the documentation available at the following link:

[Official API references](https://reference.api.rees46.com/#introduction)

## Author

REES46, <desk@rees46.com>

## License

REES46 SDK is available under the MIT license. See the LICENSE file for more info.
