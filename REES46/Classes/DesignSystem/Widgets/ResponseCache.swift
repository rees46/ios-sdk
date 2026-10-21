import Foundation

/// Кэш ответов виджетов с данными — в памяти процесса, общий для всех виджетов.
///
/// Блок в ленте приложения пересоздаётся, когда уходит за экран и возвращается, и без
/// кэша перезапрашивал бы данные на каждый скролл. Ключ — магазин, вид запроса и его
/// параметры. Ответ живёт `ttl` (10 минут), записей не больше `capacity` (32): лишние
/// вытесняются, начиная с самой старой. Одинаковые запросы в полёте склеиваются в один.
/// Ошибки не кэшируются — следующий показ спросит заново.
final class ResponseCache {

    static let shared = ResponseCache()

    struct Key: Hashable {
        let shopId: String
        /// Вид запроса (`recommend`, `collection`…): разные виды ответы не делят.
        let kind: String
        let params: [String: String]
    }

    private struct Entry {
        let value: Any
        let storedAt: Date
        /// Порядок записи: по нему вытесняются самые старые.
        let order: Int
    }

    private let ttl: TimeInterval
    private let capacity: Int
    private let now: () -> Date
    private let lock = NSLock()
    private var entries: [Key: Entry] = [:]
    private var waiting: [Key: [(Result<Any, SdkError>) -> Void]] = [:]
    private var stored = 0

    init(ttl: TimeInterval = 10 * 60, capacity: Int = 32, now: @escaping () -> Date = Date.init) {
        self.ttl = ttl
        self.capacity = capacity
        self.now = now
    }

    /// Ответ по ключу. Из кэша — сразу, на потоке вызова; иначе через `load` — на потоке,
    /// где `load` завершится. Пока запрос с этим ключом в полёте, повторные вызовы ждут
    /// его ответа, а не запрашивают снова.
    func fetch<Value>(
        _ key: Key,
        load: (@escaping (Result<Value, SdkError>) -> Void) -> Void,
        completion: @escaping (Result<Value, SdkError>) -> Void
    ) {
        let waiter: (Result<Any, SdkError>) -> Void = { result in
            switch result {
            case .success(let value as Value): completion(.success(value))
            // Под одним ключом пришёл ответ другого типа — ключ собран неверно.
            case .success: completion(.failure(.decodeError))
            case .failure(let error): completion(.failure(error))
            }
        }

        lock.lock()
        if let entry = entries[key] {
            if now().timeIntervalSince(entry.storedAt) < ttl, let value = entry.value as? Value {
                lock.unlock()
                completion(.success(value))
                return
            }
            entries[key] = nil
        }
        if waiting[key] != nil {
            waiting[key]?.append(waiter)
            lock.unlock()
            return
        }
        waiting[key] = [waiter]
        lock.unlock()

        load { [self] result in
            lock.lock()
            let waiters = waiting.removeValue(forKey: key) ?? []
            if case .success(let value) = result { store(value, for: key) }
            lock.unlock()
            let shared = result.map { $0 as Any }
            waiters.forEach { $0(shared) }
        }
    }

    /// Забыть все ответы. Запросы в полёте доходят до своих ожидающих как обычно.
    func removeAll() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    /// Вызывается под замком.
    private func store(_ value: Any, for key: Key) {
        stored += 1
        entries[key] = Entry(value: value, storedAt: now(), order: stored)
        while entries.count > capacity,
              let oldest = entries.min(by: { $0.value.order < $1.value.order })?.key {
            entries[oldest] = nil
        }
    }
}
