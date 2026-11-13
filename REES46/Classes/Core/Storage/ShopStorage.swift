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
