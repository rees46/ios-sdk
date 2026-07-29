//
//  KeychainInitStoreImpl.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Keychain-backed [KeychainInitStore]: reads and writes the shop's init blob under a per-shop account
 ([KeychainPartition]) via [InitService], instead of the single bundle-id-keyed item all shops used to
 share.

 On construction it runs a one-time adoption of the pre-partition item so an existing (upgraded)
 install keeps its did across a reinstall: the first shop to initialize copies the legacy blob into
 its own account and then deletes the legacy item (consume-by-delete), so a second shop cannot clone
 the same identity.
 */
final class KeychainInitStoreImpl: KeychainInitStore {

    private let service: String
    private let account: String

    init(shopId: String, service: String) {
        self.service = service
        self.account = KeychainPartition.account(shopId: shopId, service: service)
        adoptLegacyIfNeeded()
    }

    func readInitData() -> Data? {
        try? InitService.getKeychainDidToken(identifier: account, instanceKeychainService: service)
    }

    func writeInitData(_ data: Data) {
        try? InitService.upsertKeychainDidToken(data, identifier: account, instanceKeychainService: service)
    }

    func clear() {
        try? InitService.deleteKeychainDidToken(identifier: account, instanceKeychainService: service)
    }

    /// Copies the pre-partition keychain blob into this shop's account exactly once, then removes the
    /// legacy item. No-op when this shop already has its own blob, when nothing legacy exists, or when
    /// a previous shop already consumed it.
    private func adoptLegacyIfNeeded() {
        // Already partitioned for this shop — nothing to adopt.
        if (try? InitService.getKeychainDidToken(identifier: account, instanceKeychainService: service)) != nil {
            return
        }

        let legacyAccount = KeychainPartition.legacyAccount(service: service)
        guard legacyAccount != account,
              let legacy = try? InitService.getKeychainDidToken(
                identifier: legacyAccount,
                instanceKeychainService: service
              )
        else { return }

        try? InitService.upsertKeychainDidToken(legacy, identifier: account, instanceKeychainService: service)
        try? InitService.deleteKeychainDidToken(identifier: legacyAccount, instanceKeychainService: service)
    }
}
