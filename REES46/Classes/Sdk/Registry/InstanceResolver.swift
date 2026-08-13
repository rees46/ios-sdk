//
//  InstanceResolver.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 The outcome of resolving a `shopId` (or none) against the live and pending shops.

 Kept a plain value type so the resolution rules can be tested without constructing or initializing
 an SDK. Conforms to `Equatable` for exhaustive table tests.
 */
internal enum InstanceResolution: Equatable {
    /// An initialized instance exists for this shop — return it.
    case existing(String)
    /// A registration exists but is not initialized yet — materialize it now.
    case pending(String)
    /// No live instance and no registration matches — raise `unknownShopId`.
    case notRegistered
    /// No `shopId` given and more than one shop registered — raise `ambiguousShop`.
    case ambiguous
}

/**
 Pure decision logic behind the future `Rees46.instance(for:)` (R3): given the requested `shopId`
 (or none) and the sets of live and pending shops, decides which instance to return, whether one must
 be lazily materialized, or which error to raise. Side-effect-free — mirror of the Android
 `InstanceResolver`.
 */
internal enum InstanceResolver {

    static func resolve(
        requestedShopId: String?,
        liveShopIds: Set<String>,
        pendingShopIds: Set<String>
    ) -> InstanceResolution {
        if let requested = requestedShopId {
            if liveShopIds.contains(requested) { return .existing(requested) }
            if pendingShopIds.contains(requested) { return .pending(requested) }
            return .notRegistered
        }

        let allShopIds = liveShopIds.union(pendingShopIds)
        switch allShopIds.count {
        case 0:
            return .notRegistered
        case 1:
            let only = allShopIds.first!
            return liveShopIds.contains(only) ? .existing(only) : .pending(only)
        default:
            return .ambiguous
        }
    }
}
