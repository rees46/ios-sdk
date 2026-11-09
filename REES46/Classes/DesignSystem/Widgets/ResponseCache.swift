import Foundation

/// Кэш ответов виджетов с данными — в памяти процесса, общий для всех виджетов.
///
/// Блок в ленте приложения пересоздаётся, когда уходит за экран и возвращается, и без
/// кэша перезапрашивал бы данные на каждый скролл. Ключ — магазин, вид запроса и его
/// параметры. Ответ живёт `ttl` (10 минут), записей не больше `capacity` (32): лишние
/// вытесняются, начиная с самой старой. Одинаковые запросы в полёте склеиваются в один.
/// Ошибки не кэшируются — следующий показ спросит заново.
///
/// Запрос в полёте не держит ключ вечно: SDK может долго ждать сети, поэтому к загрузке
/// старше `staleAfter` (30 секунд) уже не присоединяются — начинается новая. Каждая
/// загрузка — своё поколение: старая отдаёт ответ только своим ожидающим и в кэш его
/// не кладёт, если после неё по ключу началась другая загрузка или был `clear()`.
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

    /// Тот, кто ждёт ответа загрузки. Поля меняются только под замком кэша.
    private final class Waiter {
        let deliver: (Result<Any, SdkError>) -> Void
        var cancelled = false

        init(_ deliver: @escaping (Result<Any, SdkError>) -> Void) {
            self.deliver = deliver
        }
    }

    /// Загрузка в полёте. Поля меняются только под замком кэша.
    private final class Flight {
        let generation: Int
        let startedAt: Date
        var waiters: [Waiter] = []

        init(generation: Int, startedAt: Date) {
            self.generation = generation
            self.startedAt = startedAt
        }
    }

    private let ttl: TimeInterval
    private let capacity: Int
    private let staleAfter: TimeInterval
    private let now: () -> Date
    private let lock = NSLock()
    private var entries: [Key: Entry] = [:]
    private var flights: [Key: Flight] = [:]
    /// Поколение последней загрузки по ключу: в кэш ложится только её ответ.
    private var latest: [Key: Int] = [:]
    private var generation = 0
    private var stored = 0

    init(
        ttl: TimeInterval = 10 * 60,
        capacity: Int = 32,
        staleAfter: TimeInterval = 30,
        now: @escaping () -> Date = Date.init
    ) {
        self.ttl = ttl
        self.capacity = capacity
        self.staleAfter = staleAfter
        self.now = now
    }

    /// Ответ по ключу. Из кэша — сразу, на потоке вызова; иначе через `load` — на потоке,
    /// где `load` завершится. К загрузке этого ключа моложе `staleAfter` вызов
    /// присоединяется, а не запрашивает снова. `force` — мимо готового ответа и мимо
    /// загрузки в полёте: так грузит «Повторить».
    ///
    /// - Returns: отписка. Отписанный ответа не получит; когда отписались все, загрузка
    ///   перестаёт быть «в полёте», и следующий вызов грузит ключ заново.
    @discardableResult
    func fetch<Value>(
        _ key: Key,
        force: Bool = false,
        load: (@escaping (Result<Value, SdkError>) -> Void) -> Void,
        completion: @escaping (Result<Value, SdkError>) -> Void
    ) -> Cancellable {
        let waiter = Waiter { result in
            switch result {
            case .success(let value as Value): completion(.success(value))
            // Под одним ключом пришёл ответ другого типа — ключ собран неверно.
            case .success: completion(.failure(.decodeError))
            case .failure(let error): completion(.failure(error))
            }
        }

        lock.lock()
        let time = now()
        if let entry = entries[key], time.timeIntervalSince(entry.storedAt) >= ttl {
            entries[key] = nil
        }
        if !force, let value = entries[key]?.value as? Value {
            lock.unlock()
            completion(.success(value))
            return .noop
        }
        if !force, let flight = flights[key], time.timeIntervalSince(flight.startedAt) < staleAfter {
            flight.waiters.append(waiter)
            lock.unlock()
            return cancellation(of: waiter, in: flight, key: key)
        }
        generation += 1
        let flight = Flight(generation: generation, startedAt: time)
        flight.waiters = [waiter]
        flights[key] = flight
        latest[key] = flight.generation
        lock.unlock()

        let handle = cancellation(of: waiter, in: flight, key: key)
        load { [self] result in finish(flight, key: key, result: result.map { $0 as Any }) }
        return handle
    }

    /// Забыть ответы и загрузки в полёте. Те доходят до своих ожидающих, но в кэш
    /// уже не ложатся.
    func clear() {
        lock.lock()
        entries.removeAll()
        flights.removeAll()
        latest.removeAll()
        lock.unlock()
    }

    private func cancellation(of waiter: Waiter, in flight: Flight, key: Key) -> Cancellable {
        Cancellable { [weak self] in
            guard let self else { return }
            self.lock.lock()
            waiter.cancelled = true
            flight.waiters.removeAll { $0 === waiter }
            if flight.waiters.isEmpty, self.flights[key] === flight { self.flights[key] = nil }
            self.lock.unlock()
        }
    }

    private func finish(_ flight: Flight, key: Key, result: Result<Any, SdkError>) {
        lock.lock()
        let waiters = flight.waiters
        flight.waiters = []
        if flights[key] === flight { flights[key] = nil }
        if latest[key] == flight.generation {
            latest[key] = nil
            if case .success(let value) = result { store(value, for: key) }
        }
        lock.unlock()
        for waiter in waiters {
            // Отписка могла прийти, пока ответ раздаётся другим.
            lock.lock()
            let cancelled = waiter.cancelled
            lock.unlock()
            if !cancelled { waiter.deliver(result) }
        }
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
