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

/// Картинка фона слайда от встроенного загрузчика: обычная — уже раскодированная, GIF —
/// сырые байты с длинами кадров (кадры раскодирует проигрыватель слайда).
enum PersonalizationStoryPicture {
    case image(UIImage)
    case gif(PersonalizationStoryGif)
}

/// Картинки слайдов: память, диск и одна загрузка на адрес. В отличие от загрузчика карточек,
/// сообщает о готовности — по ней слайд запускает отсчёт. Картинка отдаётся уже
/// раскодированной, чтобы первый кадр не декодировался на главном потоке; GIF — сырыми
/// байтами: в памяти и на диске лежит файл, а не кадры.
final class PersonalizationStoryImages {

    static let shared = PersonalizationStoryImages()

    /// Обёртка для `NSCache`: он хранит только классы.
    private final class Entry {
        let picture: PersonalizationStoryPicture

        init(_ picture: PersonalizationStoryPicture) {
            self.picture = picture
        }
    }

    private let cache: PersonalizationStoryMediaCache
    private let session: URLSession
    private let memory = NSCache<NSString, Entry>()
    private let queue = DispatchQueue(label: "personalization.stories.images", qos: .userInitiated)
    /// Кто ждёт адрес; трогается только на главном потоке.
    private var waiting: [String: [(PersonalizationStoryPicture?) -> Void]] = [:]

    init(cache: PersonalizationStoryMediaCache = .shared, session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    /// Картинка из памяти, если она уже есть.
    func cached(_ url: String) -> PersonalizationStoryPicture? {
        memory.object(forKey: url as NSString)?.picture
    }

    /// Отдаёт картинку или `nil`, если она не загрузилась. Из памяти — сразу, иначе
    /// на главном потоке. Вызывать с главного потока.
    func load(_ url: String, completion: @escaping (PersonalizationStoryPicture?) -> Void) {
        if let cached = cached(url) {
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
               let picture = Self.decode(data) {
                finish(url, picture)
                return
            }
            guard let link = URL(string: url) else {
                finish(url, nil)
                return
            }
            session.dataTask(with: link) { [self] data, response, _ in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                guard let data, (200..<300).contains(status), let picture = Self.decode(data) else {
                    finish(url, nil)
                    return
                }
                cache.store(data, for: url)
                finish(url, picture)
            }.resume()
        }
    }

    /// Заранее кладёт картинку в кэш — следующий слайд откроется без ожидания.
    /// У GIF — только байты и длины кадров: кадры раскодирует слайд, когда встанет.
    func prefetch(_ url: String?) {
        guard let url, !url.isEmpty, cached(url) == nil else { return }
        MainThread.run { self.load(url) { _ in } }
    }

    private func finish(_ url: String, _ picture: PersonalizationStoryPicture?) {
        if let picture { memory.setObject(Entry(picture), forKey: url as NSString) }
        MainThread.run { [self] in
            let callbacks = waiting.removeValue(forKey: url) ?? []
            callbacks.forEach { $0(picture) }
        }
    }

    /// GIF узнаётся по сигнатуре; нечитаемый GIF — как битое фото, `nil`.
    static func decode(_ data: Data) -> PersonalizationStoryPicture? {
        if PersonalizationStoryGif.isGif(data) {
            return PersonalizationStoryGif(data: data).map { .gif($0) }
        }
        guard let image = UIImage(data: data) else { return nil }
        if #available(iOS 15.0, *) {
            return .image(image.preparingForDisplay() ?? image)
        }
        return .image(image)
    }
}

extension PersonalizationStoryImages {

    /// Картинка компонента сторис (аватар, товар, постер): загрузчиком хоста, иначе встроенным.
    /// Встроенный показывает у GIF только первый кадр — анимируется лишь фон слайда.
    /// Пустой адрес встроенному тоже передаётся — он снимает недокачанную прошлую загрузку
    /// этого `imageView`, и чужая картинка не появится в переиспользованной вью.
    static func load(into imageView: UIImageView, url: String?, loader: ((UIImageView, String) -> Void)?) {
        let link = url.flatMap { $0.isEmpty ? nil : $0 }
        guard let loader else {
            SearchImages.shared.load(imageView, url: link)
            return
        }
        guard let link else {
            imageView.image = nil
            return
        }
        loader(imageView, link)
    }
}
