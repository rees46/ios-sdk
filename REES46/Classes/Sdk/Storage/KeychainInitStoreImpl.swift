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
 the same identity. The same adoption covers items an earlier build left under another service
 ([previousServices]) — the app switched the package manager the SDK is linked through.
 */
final class KeychainInitStoreImpl: KeychainInitStore {

    private let service: String
    private let account: String
    private let shopId: String
    private let previousServices: [String]

    init(shopId: String, service: String, previousServices: [String] = []) {
        self.service = service
        self.account = KeychainPartition.account(shopId: shopId, service: service)
        self.shopId = shopId
        self.previousServices = previousServices.filter { $0 != service }
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

    /// Copies an older keychain blob into this shop's account exactly once, then removes the source
    /// item. Sources, in order: the pre-partition item under this service, then this shop's item and the
    /// pre-partition item under each of [previousServices]. No-op when this shop already has its own
    /// blob, when no source exists, or when a previous shop already consumed it.
    private func adoptLegacyIfNeeded() {
        // Already partitioned for this shop — nothing to adopt.
        if (try? InitService.getKeychainDidToken(identifier: account, instanceKeychainService: service)) != nil {
            return
        }

        var sources = [(service: service, account: KeychainPartition.legacyAccount(service: service))]
        for previous in previousServices {
            sources.append((previous, KeychainPartition.account(shopId: shopId, service: previous)))
            sources.append((previous, KeychainPartition.legacyAccount(service: previous)))
        }

        for source in sources where source.service != service || source.account != account {
            guard let legacy = try? InitService.getKeychainDidToken(
                identifier: source.account,
                instanceKeychainService: source.service
            ) else { continue }

            try? InitService.upsertKeychainDidToken(legacy, identifier: account, instanceKeychainService: service)
            try? InitService.deleteKeychainDidToken(identifier: source.account, instanceKeychainService: source.service)
            return
        }
    }
}
