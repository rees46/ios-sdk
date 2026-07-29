//
//  KeychainInitStore.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 The keychain-backed backup of a shop's init secret, behind a typed port.

 The init secret (an `InitResponse` JSON blob carrying the `did`) is mirrored into the keychain so a
 shop's identity survives an app reinstall. Partitioned per shop (see [KeychainPartition]) so two
 shops never share one item. The port keeps the keychain plumbing out of `SimplePersonalizationSDK`
 and lets an in-memory implementation stand in for tests.
 */
protocol KeychainInitStore: AnyObject {

    /// The stored init blob for this shop, or nil if none / unavailable.
    func readInitData() -> Data?

    /// Stores (or replaces) the init blob for this shop.
    func writeInitData(_ data: Data)

    /// Removes this shop's stored init blob.
    func clear()
}
