//
//  ShopStorage.swift
//  REES46
//
//  One shop's partition on the device (`sdk/core/storage.md`).
//

import Foundation

/// What one shop keeps on the device beyond its identity (`UserIdentityRepository`): the saved
/// `/init` answer, the `refused` state, the folder of its event queue, and the flags of the one-shot
/// migrations (`StorageMigrations`).
///
/// Its `UserDefaults` are the shop's partition (`StoragePartition`); its files live in the SDK's own
/// folder in Application Support, `personalization_sdk/<partition>/`, excluded from backups — not in
/// Documents, which belongs to the app and which the user sees in the Files app when the app shares it.
final class ShopStorage {

    /// The SDK's folder in Application Support.
    static let folderName = "personalization_sdk"
    static let savedInitFileName = "init.json"
    static let queueFolderName = "queue"
    /// The shop's `refused` state in its partition (with `keyScope` in a shared one).
    static let refusedKey = "personalization_sdk.refused"
    /// The push token the new core last sent to the shop for a platform, and when the send ended; a
    /// send on its way, and when it began (`sdk/core/push.md`). Each key ends with the platform.
    static let pushTokenSentKey = "personalization_sdk.push_token_sent"
    static let pushTokenSentAtKey = "personalization_sdk.push_token_sent_at"
    static let pushTokenClaimKey = "personalization_sdk.push_token_claim"
    static let pushTokenClaimAtKey = "personalization_sdk.push_token_claim_at"
    /// The platforms of `POST /mobile_push_tokens` on iOS: APNs and FCM.
    static let pushTokenPlatforms = ["ios", "ios_firebase"]

    let shopId: String
    /// The shop's partition.
    let partition: UserDefaults
    /// What the shop's own keys carry in its partition: the shop, when an app group's suite is the
    /// partition of several shops (`StoragePartition.keyScope`).
    let keyScope: String?
    /// The shop's folder; `nil` only if the system gives no Application Support folder.
    let directory: URL?
    /// The SDK's folder, which holds every shop's.
    let root: URL?
    /// Whether this storage has seen the SDK's folder excluded from backups.
    private var rootExcluded = false

    private let documents: URL?
    private let fileManager: FileManager
    private let logger: SdkLogger
    /// Reading, moving and writing the saved answer happen one at a time.
    private let lock = NSLock()

    /// - Parameters:
    ///   - storageKey: the app's prefix of the partition (`Rees46Config.storageKey`).
    ///   - root: the SDK's folder; Application Support's by default, a temporary one in tests.
    ///   - documents: where an older SDK left the saved answer; the app's Documents by default.
    init(
        shopId: String,
        storageKey: String? = nil,
        logger: SdkLogger,
        partition: UserDefaults? = nil,
        root: URL? = nil,
        documents: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.shopId = shopId
        self.partition = partition ?? StoragePartition.store(for: shopId, storageKey: storageKey)
        self.keyScope = StoragePartition.keyScope(shopId: shopId, storageKey: storageKey)
        self.fileManager = fileManager
        self.logger = logger
        let base = root ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Self.folderName, isDirectory: true)
        let folder = StoragePartition.folderName(for: shopId, storageKey: storageKey)
        self.root = base
        self.directory = base?.appendingPathComponent(folder, isDirectory: true)
        self.documents = documents ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // MARK: - The saved /init answer

    /// The last saved `/init` answer of the shop.
    var savedInitFile: URL? {
        directory?.appendingPathComponent(Self.savedInitFileName)
    }

    /// Where SDK versions before this one kept it: `Documents/<shopId>.json`.
    var legacySavedInitFile: URL? {
        documents?.appendingPathComponent(shopId + ".json")
    }

    /// The saved `/init` answer: the shop's file; otherwise the one an older SDK left in Documents,
    /// which then moves here.
    func readSavedInitAnswer() -> Data? {
        lock.lock(); defer { lock.unlock() }
        if let file = savedInitFile, let data = read(file) {
            return data
        }
        guard let legacy = legacySavedInitFile, let data = read(legacy) else { return nil }
        _ = moveLegacySavedInitLocked()
        return data
    }

    /// Saves `data` as the shop's `/init` answer, replacing the one saved before. `false` when the disk
    /// refused; logged as `storage_failed`.
    @discardableResult
    func writeSavedInitAnswer(_ data: Data) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return writeLocked(data)
    }

    /// Saves `data` only when the shop has no saved answer yet: what the old core has always done —
    /// its saved answer is the first one it got.
    func writeSavedInitAnswerIfAbsent(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        if let file = savedInitFile, fileManager.fileExists(atPath: file.path) {
            return
        }
        if let legacy = legacySavedInitFile, fileManager.fileExists(atPath: legacy.path) {
            // The answer an older SDK saved is the first one: it moves here and stays.
            if moveLegacySavedInitLocked() {
                return
            }
        }
        writeLocked(data)
    }

    /// Forgets the saved answer, here and where an older SDK left it.
    func removeSavedInitAnswer() {
        lock.lock(); defer { lock.unlock() }
        for file in [savedInitFile, legacySavedInitFile].compactMap({ $0 }) {
            remove(file, op: "remove_saved_init")
        }
    }

    /// The migration of the saved answer: `Documents/<shopId>.json` moves to the shop's folder. A
    /// legacy file next to a newer answer is dropped. `true` when nothing is left to move.
    func moveLegacySavedInitAnswer() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return moveLegacySavedInitLocked()
    }

    // MARK: - refused

    /// The shop refused the SDK (`402`, `403`, `404` to `/init`); kept until a later `/init` passes or
    /// the customer's data is deleted.
    var refused: Bool {
        get { partition.bool(forKey: refusedKey) }
        set {
            if newValue {
                partition.set(true, forKey: refusedKey)
            } else {
                partition.removeObject(forKey: refusedKey)
            }
        }
    }

    /// The key of the shop's `refused` state.
    var refusedKey: String {
        StoragePartition.scoped(Self.refusedKey, keyScope)
    }

    // MARK: - The push token sent

    /// A push token sent to the shop: its value, and when the send ended.
    struct PushTokenSent: Equatable {
        let token: String
        let at: Date
    }

    /// A send of a push token on its way, and when it began.
    struct PushTokenClaim: Equatable {
        let token: String
        let since: Date
    }

    /// The push token the new core last sent to the shop for `platform` — `ios` or `ios_firebase` —;
    /// `nil` before the first one and after `deleteUserCredentials`.
    func pushTokenSent(platform: String) -> PushTokenSent? {
        record(Self.pushTokenSentKey, Self.pushTokenSentAtKey, platform: platform).map { PushTokenSent(token: $0.0, at: $0.1) }
    }

    func setPushTokenSent(_ sent: PushTokenSent?, platform: String) {
        setRecord(sent.map { ($0.token, $0.at) }, Self.pushTokenSentKey, Self.pushTokenSentAtKey, platform: platform)
    }

    /// The send of a push token for `platform` on its way, as the process that began it marked it.
    func pushTokenClaim(platform: String) -> PushTokenClaim? {
        record(Self.pushTokenClaimKey, Self.pushTokenClaimAtKey, platform: platform).map { PushTokenClaim(token: $0.0, since: $0.1) }
    }

    func setPushTokenClaim(_ claim: PushTokenClaim?, platform: String) {
        setRecord(claim.map { ($0.token, $0.since) }, Self.pushTokenClaimKey, Self.pushTokenClaimAtKey, platform: platform)
    }

    /// Forgets every platform's sent token and send on its way: `deleteUserCredentials`.
    func forgetPushTokens() {
        for platform in Self.pushTokenPlatforms {
            setPushTokenSent(nil, platform: platform)
            setPushTokenClaim(nil, platform: platform)
        }
    }

    private func record(_ valueKey: String, _ dateKey: String, platform: String) -> (String, Date)? {
        guard let value = partition.string(forKey: scopedKey(valueKey + "." + platform)),
              let at = partition.object(forKey: scopedKey(dateKey + "." + platform)) as? Double, at.isFinite else {
            return nil
        }
        return (value, Date(timeIntervalSince1970: at))
    }

    private func setRecord(_ record: (String, Date)?, _ valueKey: String, _ dateKey: String, platform: String) {
        if let (value, at) = record {
            partition.set(value, forKey: scopedKey(valueKey + "." + platform))
            partition.set(at.timeIntervalSince1970, forKey: scopedKey(dateKey + "." + platform))
        } else {
            partition.removeObject(forKey: scopedKey(valueKey + "." + platform))
            partition.removeObject(forKey: scopedKey(dateKey + "." + platform))
        }
    }

    private func scopedKey(_ key: String) -> String {
        StoragePartition.scoped(key, keyScope)
    }

    // MARK: - The queue's folder

    /// Where the shop's event queue lives (stage 5 writes it).
    var queueDirectory: URL? {
        directory?.appendingPathComponent(Self.queueFolderName, isDirectory: true)
    }

    /// The queue's folder, made when it is missing; `nil` when it cannot be made (logged).
    func makeQueueDirectory() -> URL? {
        lock.lock(); defer { lock.unlock() }
        guard let folder = queueDirectory else {
            logger.warning(LogCode.storageFailed, "the SDK has no folder for the queue", ["op": "create_queue_dir"])
            return nil
        }
        return makeDirectory(folder, op: "create_queue_dir") ? folder : nil
    }

    /// Deletes the queue's folder with what it holds.
    func removeQueueDirectory() {
        lock.lock(); defer { lock.unlock() }
        guard let folder = queueDirectory else { return }
        remove(folder, op: "remove_queue_dir")
    }

    // MARK: - Files

    private func read(_ file: URL) -> Data? {
        guard fileManager.fileExists(atPath: file.path) else { return nil }
        do {
            return try Data(contentsOf: file)
        } catch {
            logger.warning(LogCode.storageFailed, "the saved init answer could not be read", ["op": "read_saved_init", "error": SdkLogger.errorKind(error)])
            return nil
        }
    }

    @discardableResult
    private func writeLocked(_ data: Data) -> Bool {
        guard let directory = directory, let file = savedInitFile, makeDirectory(directory, op: "write_saved_init") else {
            return false
        }
        do {
            try data.write(to: file, options: .atomic)
            return true
        } catch {
            logger.warning(LogCode.storageFailed, "the init answer could not be saved", ["op": "write_saved_init", "error": SdkLogger.errorKind(error)])
            return false
        }
    }

    private func moveLegacySavedInitLocked() -> Bool {
        guard let legacy = legacySavedInitFile, fileManager.fileExists(atPath: legacy.path) else { return true }
        guard let directory = directory, let file = savedInitFile, makeDirectory(directory, op: "move_saved_init") else {
            return false
        }
        do {
            if fileManager.fileExists(atPath: file.path) {
                try fileManager.removeItem(at: legacy)
            } else {
                try fileManager.moveItem(at: legacy, to: file)
            }
            return true
        } catch {
            logger.warning(LogCode.storageFailed, "the saved init answer could not be moved", ["op": "move_saved_init", "error": SdkLogger.errorKind(error)])
            return false
        }
    }

    /// Makes `folder` when it is missing, and keeps the SDK's folder out of backups: what it holds is
    /// the device's, and a backup restored on another device would bring another device's answer and
    /// queue. Called under `lock`.
    private func makeDirectory(_ folder: URL, op: String) -> Bool {
        var isDirectory: ObjCBool = false
        if !(fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory) && isDirectory.boolValue) {
            do {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            } catch {
                logger.warning(LogCode.storageFailed, "the SDK's folder could not be made", ["op": op, "error": SdkLogger.errorKind(error)])
                return false
            }
        }
        excludeRootFromBackup()
        return true
    }

    private func excludeRootFromBackup() {
        guard !rootExcluded, var root = root else { return }
        do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try root.setResourceValues(values)
            rootExcluded = true
        } catch {
            logger.warning(LogCode.storageFailed, "the SDK's folder could not be excluded from backups", ["op": "exclude_from_backup", "error": SdkLogger.errorKind(error)])
        }
    }

    /// Removes what the customer left — the saved answer, the queue — so a failure is an `error`:
    /// the customer's data stays on the device.
    private func remove(_ item: URL, op: String) {
        guard fileManager.fileExists(atPath: item.path) else { return }
        do {
            try fileManager.removeItem(at: item)
        } catch {
            logger.error(LogCode.storageFailed, "the customer's data could not be removed", ["op": op, "error": SdkLogger.errorKind(error)])
        }
    }
}
