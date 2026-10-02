import UIKit
import AVFoundation
import CommonCrypto

// Медиа сторис: дисковый кэш, картинки и ролики слайдов. Каждый файл качается один раз —
// одновременные запросы одного адреса ждут одну загрузку, готовое берётся с диска.

/// Дисковый кэш медиа сторис: LRU на 50 МБ в `Caches/personalization_stories`, общий
/// для всех просмотрщиков. Свежесть файла — дата изменения: чтение её обновляет,
/// при переполнении уходят самые старые. Файлы, которые сейчас качаются или играют,
/// не удаляются.
final class PersonalizationStoryMediaCache {

    static let shared = PersonalizationStoryMediaCache()

    /// Предел кэша по умолчанию — 50 МБ.
    static let defaultLimit: Int64 = 50 * 1024 * 1024

    let directory: URL
    let limit: Int64

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var protectedKeys: [String: Int] = [:]

    init(directory: URL? = nil, limit: Int64 = PersonalizationStoryMediaCache.defaultLimit) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.directory = directory ?? caches.appendingPathComponent("personalization_stories", isDirectory: true)
        self.limit = limit
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    // MARK: - Имена файлов

    /// Ключ адреса: SHA-256 в hex — имя без запрещённых символов и без коллизий.
    static func key(for url: String) -> String {
        let data = Data(url.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Готовый файл. Расширение — из адреса: по нему AVFoundation узнаёт контейнер ролика.
    func fileURL(for url: String) -> URL {
        let ext = URL(string: url)?.pathExtension.lowercased() ?? ""
        let safe = ext.isEmpty || ext.count > 5 ? "bin" : ext
        return directory.appendingPathComponent(Self.key(for: url) + "." + safe)
    }

    /// Недокачанная часть ролика.
    func partURL(for url: String) -> URL {
        directory.appendingPathComponent(Self.key(for: url) + ".part")
    }

    /// Длина и тип недокачанного ролика — чтобы продолжить с того же места.
    func metaURL(for url: String) -> URL {
        directory.appendingPathComponent(Self.key(for: url) + ".meta")
    }

    // MARK: - Чтение и запись

    /// Готовый файл адреса, если он есть; обращение делает его свежим.
    func cachedFile(for url: String) -> URL? {
        let file = fileURL(for: url)
        guard fileManager.fileExists(atPath: file.path) else { return nil }
        touch(file)
        return file
    }

    /// Кладёт скачанный файл целиком и подрезает кэш.
    func store(_ data: Data, for url: String) {
        try? data.write(to: fileURL(for: url), options: .atomic)
        trim()
    }

    /// Ролик докачан: часть становится готовым файлом.
    func finishPart(for url: String) {
        let target = fileURL(for: url)
        try? fileManager.removeItem(at: target)
        try? fileManager.moveItem(at: partURL(for: url), to: target)
        try? fileManager.removeItem(at: metaURL(for: url))
        trim()
    }

    func size(of file: URL) -> Int64 {
        let attributes = try? fileManager.attributesOfItem(atPath: file.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func touch(_ file: URL) {
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
    }

    // MARK: - LRU

    /// Файлы адреса не удаляются, пока он защищён: идёт загрузка или ролик играет.
    func protect(_ url: String) {
        let key = Self.key(for: url)
        lock.lock()
        protectedKeys[key, default: 0] += 1
        lock.unlock()
    }

    func unprotect(_ url: String) {
        let key = Self.key(for: url)
        lock.lock()
        if let count = protectedKeys[key], count > 1 {
            protectedKeys[key] = count - 1
        } else {
            protectedKeys[key] = nil
        }
        lock.unlock()
    }

    /// Подрезает кэш до предела: удаляет самые давние по дате изменения файлы,
    /// пропуская защищённые. Недокачанная часть уходит вместе со своими метаданными.
    func trim() {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return }
        var entries = files.compactMap { file -> (url: URL, date: Date, size: Int64)? in
            guard let values = try? file.resourceValues(forKeys: Set(keys)) else { return nil }
            return (file, values.contentModificationDate ?? .distantPast, Int64(values.fileSize ?? 0))
        }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > limit else { return }
        lock.lock()
        let busy = Set(protectedKeys.keys)
        lock.unlock()
        entries.sort { $0.date < $1.date }
        for entry in entries where total > limit {
            let key = entry.url.deletingPathExtension().lastPathComponent
            guard !busy.contains(key) else { continue }
            if (try? fileManager.removeItem(at: entry.url)) != nil {
                total -= entry.size
            }
        }
    }
}

/// Картинки слайдов: память, диск и одна загрузка на адрес. В отличие от загрузчика карточек,
/// сообщает о готовности — по ней слайд запускает отсчёт. Картинка отдаётся уже
/// раскодированной, чтобы первый кадр не декодировался на главном потоке.
final class PersonalizationStoryImages {

    static let shared = PersonalizationStoryImages()

    private let cache: PersonalizationStoryMediaCache
    private let session: URLSession
    private let memory = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "personalization.stories.images", qos: .userInitiated)
    /// Кто ждёт адрес; трогается только на главном потоке.
    private var waiting: [String: [(UIImage?) -> Void]] = [:]

    init(cache: PersonalizationStoryMediaCache = .shared, session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    /// Картинка из памяти, если она уже есть.
    func cachedImage(_ url: String) -> UIImage? {
        memory.object(forKey: url as NSString)
    }

    /// Отдаёт картинку или `nil`, если она не загрузилась. Из памяти — сразу, иначе
    /// на главном потоке. Вызывать с главного потока.
    func load(_ url: String, completion: @escaping (UIImage?) -> Void) {
        if let cached = cachedImage(url) {
            completion(cached)
            return
        }
        if waiting[url] != nil {
            waiting[url]?.append(completion)
            return
        }
        waiting[url] = [completion]
        queue.async { [self] in
            if let file = cache.cachedFile(for: url),
               let data = try? Data(contentsOf: file),
               let image = Self.decode(data) {
                finish(url, image)
                return
            }
            guard let link = URL(string: url) else {
                finish(url, nil)
                return
            }
            session.dataTask(with: link) { [self] data, response, _ in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                guard let data, (200..<300).contains(status), let image = Self.decode(data) else {
                    finish(url, nil)
                    return
                }
                cache.store(data, for: url)
                finish(url, image)
            }.resume()
        }
    }

    /// Заранее кладёт картинку в кэш — следующий слайд откроется без ожидания.
    func prefetch(_ url: String?) {
        guard let url, !url.isEmpty, cachedImage(url) == nil else { return }
        MainThread.run { self.load(url) { _ in } }
    }

    private func finish(_ url: String, _ image: UIImage?) {
        if let image { memory.setObject(image, forKey: url as NSString) }
        MainThread.run { [self] in
            let callbacks = waiting.removeValue(forKey: url) ?? []
            callbacks.forEach { $0(image) }
        }
    }

    private static func decode(_ data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        if #available(iOS 15.0, *) {
            return image.preparingForDisplay() ?? image
        }
        return image
    }
}
