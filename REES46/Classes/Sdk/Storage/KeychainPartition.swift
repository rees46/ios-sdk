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

    /// The service of the SDK's keychain items when the binary it is linked into has no bundle id;
    /// what the SDK used then.
    static let fallbackService = "com.rees46.sdk"

    /**
     The service of the SDK's keychain items, computed exactly as it always was: the bundle id of the
     binary the SDK is linked into, `Bundle(for:)` of a class of this module —
     `org.cocoapods.REES46` for the framework CocoaPods builds with `use_frameworks!`, the app's bundle
     id when the SDK is linked into the app, the id of an app's own framework that links it statically.
     */
    static let service: String = Bundle(for: KeychainServiceAnchor.self).bundleIdentifier ?? fallbackService

    /// The services an earlier build of the same app may have kept the items under, in another link
    /// mode: the CocoaPods framework's and the app's own; the current one left out.
    static var previousServices: [String] {
        previousServices(current: service, appBundleId: Bundle.main.bundleIdentifier)
    }

    static func previousServices(current: String, appBundleId: String?) -> [String] {
        var services = [cocoaPodsFrameworkService]
        if let app = appBundleId, !app.isEmpty, app != cocoaPodsFrameworkService {
            services.append(app)
        }
        return services.filter { $0 != current }
    }
}

/// The class `KeychainPartition.service` takes the bundle of. It must stay in this module (the SDK's
/// own target): moved to another module, `Bundle(for:)` answers with that module's bundle, the
/// service changes, and every install loses the keychain backup of its device id.
final class KeychainServiceAnchor {}
