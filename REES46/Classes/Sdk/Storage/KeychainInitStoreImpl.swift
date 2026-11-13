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
 its own account and then deletes the legacy item (consume-by-delete). The same adoption covers items
 an earlier build left under another service ([previousServices]) — the app switched the package
 manager the SDK is linked through. With the shop's partition at hand the adoption runs once
 (`StorageMigrations.Step.keychainItem`); a keychain that does not answer — locked, say — leaves it for
 the next launch.
 */
final class KeychainInitStoreImpl: KeychainInitStore {

    private let service: String
    private let account: String
    private let shopId: String
    private let previousServices: [String]

    /// - Parameter partition: the shop's partition, where the adoption marks itself done.
    init(shopId: String, service: String, previousServices: [String] = [], partition: UserDefaults? = nil) {
        self.service = service
        self.account = KeychainPartition.account(shopId: shopId, service: service)
        self.shopId = shopId
        self.previousServices = previousServices.filter { $0 != service }
        if let partition = partition {
            StorageMigrations.once(.keychainItem, in: partition) { adoptLegacyIfNeeded() }
        } else {
            _ = adoptLegacyIfNeeded()
        }
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

    /// What the keychain answered for one item.
    private enum Lookup {
        case found(Data)
        case missing
        /// The keychain did not answer: locked, or another error.
        case unanswered
    }

    private static func lookup(account: String, service: String) -> Lookup {
        do {
            return .found(try InitService.getKeychainDidToken(identifier: account, instanceKeychainService: service))
        } catch KeychainError.itemNotFound {
            return .missing
        } catch {
            return .unanswered
        }
    }

    /// Copies an older keychain blob into this shop's account exactly once, then removes the source
    /// item. Sources, in order: the pre-partition item under this service, then this shop's item and the
    /// pre-partition item under each of [previousServices]. No-op when this shop already has its own
    /// blob, when no source exists, or when a previous shop already consumed it.
    ///
    /// Returns whether the keychain answered for every item it looked at: `false` leaves the adoption
    /// to the next launch.
    private func adoptLegacyIfNeeded() -> Bool {
        // Two shops made on two threads must not both find the legacy item before either consumed it.
        StorageMigrations.adoptionLock.lock()
        defer { StorageMigrations.adoptionLock.unlock() }
        switch Self.lookup(account: account, service: service) {
        case .found:
            // Already partitioned for this shop — nothing to adopt.
            return true
        case .unanswered:
            return false
        case .missing:
            break
        }

        var sources = [(service: service, account: KeychainPartition.legacyAccount(service: service))]
        for previous in previousServices {
            sources.append((previous, KeychainPartition.account(shopId: shopId, service: previous)))
            sources.append((previous, KeychainPartition.legacyAccount(service: previous)))
        }

        var answered = true
        for source in sources where source.service != service || source.account != account {
            switch Self.lookup(account: source.account, service: source.service) {
            case .missing:
                continue
            case .unanswered:
                answered = false
                continue
            case .found(let legacy):
                do {
                    try InitService.upsertKeychainDidToken(legacy, identifier: account, instanceKeychainService: service)
                } catch {
                    return false
                }
                // Consumed, not copied: the pre-partition item carries no shop, so the first shop to
                // initialize takes it, and a second shop must not find it and clone the same did. The
                // rule that a migration keeps its source until a successful /init does not hold here.
                try? InitService.deleteKeychainDidToken(identifier: source.account, instanceKeychainService: source.service)
                return true
            }
        }
        return answered
    }
}
