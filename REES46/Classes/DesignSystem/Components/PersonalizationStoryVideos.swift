import Foundation
import AVFoundation

/// Загрузка одного ролика: последовательно, в недокачанную часть дискового кэша.
/// Живёт на очереди `PersonalizationStoryVideos.queue` — все поля трогаются только там.
/// Прерванная загрузка продолжается с того же байта (`Range`), докачанная становится
/// готовым файлом кэша.
final class PersonalizationStoryVideoDownload {

    let url: String
    let remote: URL
    /// Полная длина ролика, когда сервер её назвал.
    var length: Int64?
    var mimeType: String?
    /// Сколько байт уже на диске.
    var received: Int64 = 0
    var isComplete = false
    var error: Error?
    var task: URLSessionDataTask?
    /// Плееры, которые читают ролик: без них загрузка останавливается.
    var clients = 0
    /// Предзагрузка начала: без плееров загрузка встаёт после стольких байт.
    var headLimit: Int64?
    /// Кого будить, когда пришли данные или загрузка кончилась.
    var observers: [ObjectIdentifier: () -> Void] = [:]

    private let cache: PersonalizationStoryMediaCache
    private var writer: FileHandle?

    init?(url: String, cache: PersonalizationStoryMediaCache) {
        guard let remote = URL(string: url), remote.scheme?.hasPrefix("http") == true else { return nil }
        self.url = url
        self.remote = remote
        self.cache = cache
        restore()
    }

    /// Файл, из которого сейчас читать: готовый или недокачанная часть.
    var fileURL: URL {
        isComplete ? cache.fileURL(for: url) : cache.partURL(for: url)
    }

    /// Состояние прошлой загрузки с диска: сколько байт уже есть, длина и тип ролика.
    private func restore() {
        let part = cache.partURL(for: url)
        guard FileManager.default.fileExists(atPath: part.path) else { return }
        received = cache.size(of: part)
        guard let data = try? Data(contentsOf: cache.metaURL(for: url)),
              let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Без длины часть бесполезна: Range-запрос не проверить.
            received = 0
            try? FileManager.default.removeItem(at: part)
            return
        }
        length = (meta["length"] as? NSNumber)?.int64Value
        mimeType = meta["mime"] as? String
    }

    private func saveMeta() {
        var meta: [String: Any] = [:]
        if let length { meta["length"] = NSNumber(value: length) }
        if let mimeType { meta["mime"] = mimeType }
        if let data = try? JSONSerialization.data(withJSONObject: meta) {
            try? data.write(to: cache.metaURL(for: url), options: .atomic)
        }
    }

    // MARK: - Сеть

    /// Запрос продолжения: с первого недостающего байта.
    func request() -> URLRequest {
        var request = URLRequest(url: remote)
        if received > 0 {
            request.setValue("bytes=\(received)-", forHTTPHeaderField: "Range")
        }
        return request
    }

    /// Ответ сервера. `false` — ролика по адресу нет, загрузку прервать.
    func accept(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        switch http.statusCode {
        case 206:
            // `value(forHTTPHeaderField:)` только с iOS 13 — заголовок ищется без учёта регистра сам.
            let range = http.allHeaderFields.first { ($0.key as? String)?.lowercased() == "content-range" }?.value as? String
            length = Self.total(fromContentRange: range) ?? length
        case 200:
            // Сервер Range не понял — качаем заново с нуля.
            received = 0
            try? FileManager.default.removeItem(at: cache.partURL(for: url))
            length = http.expectedContentLength > 0 ? http.expectedContentLength : nil
        default:
            return false
        }
        mimeType = http.mimeType ?? mimeType
        saveMeta()
        let part = cache.partURL(for: url)
        if !FileManager.default.fileExists(atPath: part.path) {
            FileManager.default.createFile(atPath: part.path, contents: nil)
        }
        writer = try? FileHandle(forWritingTo: part)
        writer?.seekToEndOfFile()
        return writer != nil
    }

    func append(_ data: Data) {
        writer?.write(data)
        received += Int64(data.count)
    }

    /// Загрузка кончилась сама: успехом — часть становится готовым файлом.
    func finish(error: Error?) {
        writer?.closeFile()
        writer = nil
        task = nil
        if let error {
            self.error = error
        } else {
            if length == nil { length = received }
            isComplete = true
            cache.finishPart(for: url)
        }
        notify()
    }

    /// Загрузку остановили мы: часть остаётся на диске до следующего раза.
    func pause() {
        task?.cancel()
        task = nil
        writer?.closeFile()
        writer = nil
    }

    func notify() {
        observers.values.forEach { $0() }
    }

    /// Полная длина из `Content-Range: bytes 0-99/1234`.
    static func total(fromContentRange value: String?) -> Int64? {
        guard let value, let slash = value.lastIndex(of: "/") else { return nil }
        return Int64(value[value.index(after: slash)...].trimmingCharacters(in: .whitespaces))
    }
}

/// Ролики сторис: каждый качается один раз, последовательно, в дисковый кэш. Плеер читает
/// недокачанный ролик через `AVAssetResourceLoader` по мере загрузки — играть можно, не дожидаясь
/// конца файла; докачанный играет прямо из кэша. Следующему слайду заранее качается начало ролика.
final class PersonalizationStoryVideos: NSObject, URLSessionDataDelegate {

    static let shared = PersonalizationStoryVideos()

    /// Схема адреса для загрузчика: с ней AVFoundation отдаёт чтение нам.
    static let scheme = "personalization-stories"
    /// Сколько качать заранее для следующего слайда — начало ролика.
    static let headBytes: Int64 = 1024 * 1024

    let queue = DispatchQueue(label: "personalization.stories.videos")
    let cache: PersonalizationStoryMediaCache
    private var downloads: [String: PersonalizationStoryVideoDownload] = [:]
    private var byTask: [Int: PersonalizationStoryVideoDownload] = [:]
    private lazy var session: URLSession = {
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.underlyingQueue = queue
        return URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
    }()

    init(cache: PersonalizationStoryMediaCache = .shared) {
        self.cache = cache
    }

    // MARK: - Плеер

    /// Ассет ролика для плеера и загрузчик, которого надо держать, пока ассет жив
    /// (`AVAssetResourceLoader` держит делегата слабо). Готовый файл играет напрямую.
    func asset(for url: String) -> (asset: AVURLAsset, loader: PersonalizationStoryVideoLoader?)? {
        if let file = cache.cachedFile(for: url) {
            return (AVURLAsset(url: file), nil)
        }
        guard var parts = URLComponents(string: url), parts.scheme?.hasPrefix("http") == true else { return nil }
        parts.scheme = Self.scheme
        guard let custom = parts.url else { return nil }
        let download: PersonalizationStoryVideoDownload? = queue.sync { self.download(for: url) }
        guard let download else { return nil }
        let asset = AVURLAsset(url: custom)
        let loader = PersonalizationStoryVideoLoader(videos: self, download: download)
        asset.resourceLoader.setDelegate(loader, queue: queue)
        return (asset, loader)
    }

    /// Начало ролика следующего слайда — заранее, чтобы он пошёл сразу.
    func prefetchHead(_ url: String?) {
        guard let url, cache.cachedFile(for: url) == nil else { return }
        queue.async { [self] in
            guard let download = download(for: url), !download.isComplete, download.received < Self.headBytes else { return }
            download.headLimit = max(download.headLimit ?? 0, Self.headBytes)
            start(download)
        }
    }

    // MARK: - Загрузки (на `queue`)

    private func download(for url: String) -> PersonalizationStoryVideoDownload? {
        if let existing = downloads[url] { return existing }
        guard let created = PersonalizationStoryVideoDownload(url: url, cache: cache) else { return nil }
        downloads[url] = created
        cache.protect(url)
        return created
    }

    func attach(_ download: PersonalizationStoryVideoDownload) {
        download.clients += 1
        download.error = nil
        start(download)
    }

    /// Плеер ушёл. Без плееров и предзагрузки загрузка встаёт, недокачанное остаётся на диске.
    func detach(_ download: PersonalizationStoryVideoDownload) {
        download.clients = max(0, download.clients - 1)
        guard download.clients == 0 else { return }
        if download.task != nil, download.received >= (download.headLimit ?? 0) {
            download.pause()
        }
        release(download)
    }

    func start(_ download: PersonalizationStoryVideoDownload) {
        guard !download.isComplete, download.task == nil else { return }
        let task = session.dataTask(with: download.request())
        download.task = task
        byTask[task.taskIdentifier] = download
        task.resume()
    }

    /// Загрузка больше никому не нужна — её место в памяти освобождается, файлы остаются.
    private func release(_ download: PersonalizationStoryVideoDownload) {
        guard download.clients == 0, download.task == nil, downloads[download.url] === download else { return }
        downloads[download.url] = nil
        cache.unprotect(download.url)
        if download.isComplete { cache.trim() }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let download = byTask[dataTask.taskIdentifier], download.accept(response) else {
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let download = byTask[dataTask.taskIdentifier], download.task === dataTask else { return }
        download.append(data)
        download.notify()
        // Начало для следующего слайда скачано, а смотреть его ещё некому — хватит.
        if download.clients == 0, let limit = download.headLimit, download.received >= limit {
            download.headLimit = nil
            download.pause()
            byTask[dataTask.taskIdentifier] = nil
            release(download)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let download = byTask.removeValue(forKey: task.taskIdentifier), download.task === task else { return }
        // Отказ сервера (`.cancel` в ответе) приходит сюда же ошибкой отмены.
        download.finish(error: error)
        release(download)
    }
}

/// Чтение недокачанного ролика для `AVPlayer`: отвечает на запросы диапазонов тем, что уже
/// на диске, и ждёт остальное от загрузки. Пока загрузчик жив, ролик качается.
final class PersonalizationStoryVideoLoader: NSObject, AVAssetResourceLoaderDelegate {

    private weak var videos: PersonalizationStoryVideos?
    private let download: PersonalizationStoryVideoDownload
    private var pending: [AVAssetResourceLoadingRequest] = []

    /// Сколько отдавать плееру за раз.
    private static let chunk: Int64 = 512 * 1024

    init(videos: PersonalizationStoryVideos, download: PersonalizationStoryVideoDownload) {
        self.videos = videos
        self.download = download
        super.init()
        let id = ObjectIdentifier(self)
        videos.queue.async { [weak self] in
            download.observers[id] = { self?.process() }
            videos.attach(download)
        }
    }

    deinit {
        let id = ObjectIdentifier(self)
        let download = download
        guard let videos else { return }
        videos.queue.async {
            download.observers[id] = nil
            videos.detach(download)
        }
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        pending.append(loadingRequest)
        if download.error != nil || (download.task == nil && !download.isComplete) {
            // Прошлая попытка не удалась или загрузка стояла — плееру ролик снова нужен.
            download.error = nil
            videos?.start(download)
        }
        process()
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        pending.removeAll { $0 === loadingRequest }
    }

    /// Отвечает всем ждущим запросам, чем может; законченные убирает.
    private func process() {
        pending.removeAll { serve($0) }
    }

    /// `true` — запрос закончен.
    private func serve(_ request: AVAssetResourceLoadingRequest) -> Bool {
        if request.isCancelled || request.isFinished { return true }
        if let info = request.contentInformationRequest {
            guard let length = download.length else { return failIfNeeded(request) }
            info.contentType = Self.contentType(mime: download.mimeType, url: download.remote)
            info.contentLength = length
            info.isByteRangeAccessSupported = true
        }
        guard let data = request.dataRequest else {
            request.finishLoading()
            return true
        }
        let end = data.requestsAllDataToEndOfResource
            ? (download.length ?? .max)
            : data.requestedOffset + Int64(data.requestedLength)
        let available = min(end, download.received)
        var offset = data.currentOffset
        if offset < available, let reader = try? FileHandle(forReadingFrom: download.fileURL) {
            reader.seek(toFileOffset: UInt64(offset))
            while offset < available {
                let bytes = reader.readData(ofLength: Int(min(available - offset, Self.chunk)))
                guard !bytes.isEmpty else { break }
                data.respond(with: bytes)
                offset += Int64(bytes.count)
            }
            reader.closeFile()
        }
        if offset >= end || (download.isComplete && offset >= download.received) {
            request.finishLoading()
            return true
        }
        return failIfNeeded(request)
    }

    /// Загрузка упала — ждать нечего, запрос заканчивается её ошибкой.
    private func failIfNeeded(_ request: AVAssetResourceLoadingRequest) -> Bool {
        guard let error = download.error, download.task == nil else { return false }
        request.finishLoading(with: error)
        return true
    }

    /// UTI контейнера для плеера: по MIME ответа, иначе по расширению адреса.
    static func contentType(mime: String?, url: URL) -> String {
        switch mime?.lowercased() {
        case "video/quicktime": return "com.apple.quicktime-movie"
        case "video/x-m4v": return "com.apple.m4v-video"
        case "video/mp4": return "public.mpeg-4"
        default: break
        }
        switch url.pathExtension.lowercased() {
        case "mov": return "com.apple.quicktime-movie"
        case "m4v": return "com.apple.m4v-video"
        default: return "public.mpeg-4"
        }
    }
}
