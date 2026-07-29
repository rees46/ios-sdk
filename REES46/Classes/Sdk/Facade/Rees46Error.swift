//
//  Rees46Error.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Errors raised by `Rees46.instance(for:)` when a shop cannot be resolved.

 A Swift `enum` mirror of the Android `UnknownShopIdException` / `AmbiguousShopException` (decision №1
 — the concepts must match across platforms, expressed idiomatically per platform).
 */
public enum Rees46Error: Error {

    /// No shop is registered for the requested id — nothing registered at all, or no such shop. A
    /// registered-but-not-yet-initialized shop does **not** raise this: `instance(for:)` materializes
    /// it. The failure is a missing registration, not an instance that failed to start.
    case unknownShopId(String)

    /// `instance(for:)` was called without a `shopId` while more than one shop is registered — the
    /// default is ambiguous. Carries the sorted registered shop ids. Pass an explicit id.
    case ambiguousShop([String])
}

extension Rees46Error: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .unknownShopId(let shopId):
            let subject = shopId.isEmpty
                ? "No shop has been registered."
                : "No shop is registered for shopId=\(shopId)."
            return "\(subject) Call Rees46.initialize(...) or Rees46.register(shops:) first."
        case .ambiguousShop(let shopIds):
            return "More than one shop is registered — call Rees46.instance(for:) with an explicit " +
                "id. Registered: \(shopIds)."
        }
    }
}
