//
//  KeychainPartition.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Naming of the SDK's per-shop keychain items (R2).

 The SDK backs up the init secret (the blob that carries the `did`) in the keychain so identity
 survives an app **reinstall** — the keychain outlives the app container. Before partitioning the item
 was keyed by the bundle id alone (`service = account = bundleId`), so two shops in one app resolved to
 the same item and shop B could read shop A's did. Here the `service` stays the bundle id (namespace)
 and the `account` carries the `shop_id`, so each shop gets its own keychain slot.
 */
enum KeychainPartition {

    /// The keychain account for [shopId]'s init secret, namespaced under [service] (the bundle id).
    static func account(shopId: String, service: String) -> String {
        "\(service).\(shopId)"
    }

    /// The pre-partition account (the bundle id itself) — the one-time migration source. Existing
    /// installs stored their only item here.
    static func legacyAccount(service: String) -> String {
        service
    }

    /// The service an install linked through CocoaPods with `use_frameworks!` keeps its items under:
    /// CocoaPods gives the SDK framework this bundle id. Linked through SwiftPM the SDK lives in the app
    /// binary and `Bundle(for:)` answers with the app's bundle id instead, so an app that switches package
    /// manager would lose its keychain backup — and with it the did — on the next reinstall.
    static let cocoaPodsFrameworkService = "org.cocoapods.REES46"

    /// The service of the SDK's keychain items when the app has no bundle id; what the SDK used then.
    static let fallbackService = "com.rees46.sdk"

    /**
     The service of the SDK's keychain items, pinned to what it has always been: the bundle id of
     the binary the SDK is linked into, as `Bundle(for:)` gave it — `org.cocoapods.REES46` for the
     framework CocoaPods builds with `use_frameworks!`, the app's bundle id when the SDK is linked into
     the app (SwiftPM, a static CocoaPods build). Found by the framework's identifier, not by the
     bundle of an SDK class: moved to a folder or module of its own, the core still finds the items
     every install already has.
     */
    static let service: String = service(
        frameworkIsLoaded: Bundle(identifier: cocoaPodsFrameworkService) != nil,
        appBundleId: Bundle.main.bundleIdentifier
    )

    static func service(frameworkIsLoaded: Bool, appBundleId: String?) -> String {
        frameworkIsLoaded ? cocoaPodsFrameworkService : (appBundleId ?? fallbackService)
    }
}
