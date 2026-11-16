//
//  PendingPushEvents.swift
//  REES46
//
//  The push events of a shop that is registered and not created, on the new core (`sdk/core/push.md`,
//  `sdk/core/queue.md`): through the shop's queue on disk, without an instance.
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

/// The push events of a shop that `Rees46.register` registered and nothing created yet — the app was
/// launched by the push, say. The shop is not created for them: each event is written into the shop's
/// queue folder, `personalization_sdk/<partition>/queue/`, and sent at once under a background task,
/// with the device id the shop has stored and without `/init`. One that cannot go now — no network at a
/// cold start, a server error — stays there, and the shop's instance sends it when it is made, in this
/// launch or the next.
enum PendingPushEvents {

    /// The name of the background task that sends a pending shop's push event.
    static let backgroundTask = "com.rees46.sdk.pending_push"

    /// The seams: the network, the app's lifecycle and the clock. The tests set their own.
    static var connectivity: () -> ConnectivityMonitor = defaultConnectivity
    static var lifecycle: () -> AppLifecycle = defaultLifecycle
    static var clock: () -> Clock = defaultClock
    /// Where the identity of the time before the partitions per shop is: `.standard`.
    static var legacyIdentity: () -> UserDefaults = defaultLegacyIdentity

    private static let defaultConnectivity: () -> ConnectivityMonitor = { SystemConnectivityMonitor.shared }
    private static let defaultLifecycle: () -> AppLifecycle = { SystemAppLifecycle.shared }
    private static let defaultClock: () -> Clock = { SystemClock() }
    private static let defaultLegacyIdentity: () -> UserDefaults = { .standard }

    /// The events are written here, one at a time and off the caller's thread.
    private static let work = DispatchQueue(label: "com.rees46.sdk.pending_push", qos: .utility)

    /// Takes the event of `push` for the shop's queue. `accepted` hears, off the caller's thread, whether
    /// it was: written to disk, or — the disk refusing it — sent by the one request it then goes as. The
    /// background task begins before this returns: the app may hand the push's completion back to the
    /// system right after. The device id is the shop's (`deviceId(for:storage:)`), read off the caller's
    /// thread; without one nothing goes (`push_dropped`, `no_did`). A click stores the push as the
    /// source of the shop's `/push` events for 48 hours.
    static func take(_ push: PendingPush, event: Rees46.PushEvent, storage: ShopStorage, logger: SdkLogger, accepted: @escaping (Bool) -> Void) {
        let connectivity = self.connectivity()
        let lifecycle = self.lifecycle()
        let now = clock().now()
        let task = lifecycle.beginBackgroundTask(backgroundTask) {}
        let legacy = legacyIdentity()
        work.async {
            let deviceId = Self.deviceId(for: push, storage: storage, legacy: legacy)
            guard !deviceId.isEmpty else {
                // The shop has never had a device id here: the server sent this device no push of it.
                // Nothing is held for the message once the log says so.
                accepted(false)
                logger.warning(LogCode.pushDropped, "the shop of the push has no device id: the event was not sent", ["reason": "no_did"])
                task.cancel()
                return
            }
            if event == .clicked, let source = TrackingSourceType(rawValue: push.type) {
                TrackingSourceStoreImpl(store: storage.partition).store(type: source.rawValue, code: push.code)
            }
            let body: [String: Any] = ["code": push.code, "type": push.type]
            let client = NetworkClient(baseURL: "https://\(push.config.apiDomain)/", connectivity: connectivity, logger: logger) {
                CommonFields(
                    shopId: push.shopId,
                    deviceId: deviceId,
                    sessionId: "",
                    stream: push.config.stream,
                    segment: DeviceStore.shared.abGroup ?? ""
                )
            }
            let request = NetworkClient.Request(method: .post, path: event.path, body: body)
            EventQueue.sendDetached(
                path: event.path,
                body: body,
                createdAt: now,
                storage: storage,
                logger: logger,
                send: { await client.send(request) },
                written: { written in
                    if written {
                        accepted(true)
                    }
                },
                completion: { stored, response in
                    if !stored {
                        // Not on disk: the one request was all it had.
                        switch response.result {
                        case .success, .failure(.decoding):
                            accepted(true)
                        case .failure:
                            accepted(false)
                        }
                    }
                    task.cancel()
                }
            )
        }
    }

    /// The device id a shop that has no instance sends its push's event with: the one its instance
    /// would take without `/init` (`sdk/core/push.md`). In the order the instance takes them: the
    /// shop's storage — its partition, or the suite its `storageKey` named before it became a prefix —;
    /// the identity of the time before the partitions per shop, while no shop took it; the
    /// `Rees46Config.deviceId` the shop has not taken yet; the keychain backup of its init answer, which
    /// outlives a reinstall; the saved `/init` answer. A forced re-initialization takes none but the
    /// stored one. Reads the disk and the keychain: never on the caller's thread.
    static func deviceId(for push: PendingPush, storage: ShopStorage, legacy: UserDefaults = .standard) -> String {
        let config = push.config
        let stored = StoragePartition.deviceId(for: push.shopId, storageKey: config.storageKey)
        if !stored.isEmpty {
            return stored
        }
        guard !config.needReInitialization else { return "" }
        let partition = storage.partition
        let scope = storage.keyScope
        if StoragePartition.prefix(config.storageKey) == nil,
           !StorageMigrations.isDone(.standardIdentity, in: partition, scope: scope),
           !legacy.bool(forKey: StoragePartition.legacyConsumedFlag),
           let did = legacy.string(forKey: StoragePartition.deviceIdKey), !did.isEmpty {
            return did
        }
        if let configured = config.deviceId, !configured.isEmpty,
           !StorageMigrations.isDone(.configuredDeviceId, in: partition, scope: scope) {
            return configured
        }
        if let did = keychainDeviceId(shopId: push.shopId) {
            return did
        }
        if let data = storage.readSavedInitAnswer(), let did = savedDeviceId(in: data) {
            return did
        }
        return ""
    }

    /// The keychain backup of the shop's init answer: the shop's own item, then the ones its
    /// instance would adopt — the item from before the partitions per shop and those an earlier build
    /// kept under another service. Read only: the instance adopts them.
    private static func keychainDeviceId(shopId: String) -> String? {
        let service = KeychainPartition.service
        var sources = [
            (service, KeychainPartition.account(shopId: shopId, service: service)),
            (service, KeychainPartition.legacyAccount(service: service)),
        ]
        for previous in KeychainPartition.previousServices {
            sources.append((previous, KeychainPartition.account(shopId: shopId, service: previous)))
            sources.append((previous, KeychainPartition.legacyAccount(service: previous)))
        }
        for (service, account) in sources {
            if let data = try? InitService.getKeychainDidToken(identifier: account, instanceKeychainService: service),
               let did = savedDeviceId(in: data) {
                return did
            }
        }
        return nil
    }

    private static func savedDeviceId(in data: Data) -> String? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let did = json["did"] as? String, !did.isEmpty else { return nil }
        return did
    }

    /// Test-only: the system's seams again.
    static func reset() {
        connectivity = defaultConnectivity
        lifecycle = defaultLifecycle
        clock = defaultClock
        legacyIdentity = defaultLegacyIdentity
    }
}
