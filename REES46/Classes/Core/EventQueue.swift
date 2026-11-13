//
//  EventQueue.swift
//  REES46
//
//  The event queue of the new core (`sdk/core/queue.md`, decision 0002): events on disk, per shop,
//  in order, sent in the background and kept through no network and a restart.
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

/// What the queue needs from the instance that sends its events.
protocol EventQueueHost: AnyObject {
    /// Whether events may go out now. An instance whose session's window ran out asks for a new one
    /// here (`InitMachine.renewSession()`) and says `wait`.
    func queueGate() -> EventQueue.Gate
    /// Sends one event through the instance's client.
    func queueSend(_ request: NetworkClient.Request) async -> NetworkClient.Response
    /// Asks the shop through `/init` whether it still serves the SDK; `false` when it was not asked.
    func queueCheckShop() -> Bool
    /// The `source` a `/push` carries: the one the app stored (`tracking.setSource`), while it lasts.
    func queueSource() -> [String: String]?
    /// An event went out: the server answered `2xx`.
    func queueDelivered(_ event: EventQueue.Delivered)
    var queueEnvironment: CoreEnvironment { get }
    var queueConnectivity: ConnectivityMonitor { get }
}

/// The events of one shop: `/push`, `/push/custom`, `track/stories`, `track/slider`, `popup/showed`.
///
/// - **Accepted** is written to disk: one file per event in the shop's `queue/` folder, written
///   atomically, named by its place in the queue. An event the disk refuses is not queued: the log
///   says `storage_failed`, and it is sent once as a plain request.
/// - **In order**, one at a time. The event keeps its creation time; `time` goes only to
///   `push/custom`, the one address that reads it; `sid` is the instance's when the event goes out, and
///   the stored source is added then, to `/push` only.
/// - **Sent** when the instance is usable and its session alive, online: after `ready`, on the way to
///   the foreground and to the background, when the network comes back, on `flush()`, when an event
///   comes in, and after a pause.
/// - **Answers** (decision 0002): `2xx` deletes the event; no network waits for it, without counting;
///   a timeout is repeated after a pause, without counting; `5xx`, `408`, `410`, `417`, `426`, `429`
///   are repeated after a pause — 1 s … 5 min ±20 %, or the `Retry-After` of a `429` or `503`, which
///   no trigger cuts short — and dropped after ten; `402`, `403`, `404` pause the queue and ask the shop (`checkShop()`): `refused`
///   clears the queue, a passed check sends the event again, and the same answer to it drops it — the
///   refusal of a service, not of the shop; any other `4xx` drops it.
/// - **Limits**: an event older than seven days is dropped when its turn comes; a shop keeps at most
///   1000, the oldest go first. Every drop is `queue_dropped` with its reason.
/// - **One owner per shop.** Instances of one shop share one queue — the one of its folder — and only
///   the last one made sends; an event that another queue of the folder has on its way waits for it.
final class EventQueue {

    /// Whether events may go out.
    enum Gate {
        case open
        /// Not yet: `ready`, a new session or a check of the shop is on its way.
        case wait
        /// The shop refused: the queue is cleared.
        case refused
        /// Released.
        case closed
    }

    /// What the app's callback of one event hears: once.
    enum Outcome {
        /// The server answered `2xx`; the result is its JSON, or `decoding`.
        case sent(NetworkClient.Response)
        /// It will not go: dropped, cleared, or its instance released. `body` is the last error body.
        case failed(Rees46.SdkError, body: Data)
    }

    /// An event the server took.
    struct Delivered {
        let path: String
        let response: NetworkClient.Response
        let createdAt: Date
        let sentAt: Date
    }

    /// How long an event is kept.
    static let lifetime: TimeInterval = 7 * 24 * 60 * 60
    /// How many events a shop keeps.
    static let capacity = 1000
    /// How many passing server errors an event gets.
    static let maxAttempts = 10
    /// The answers that make the queue ask the shop.
    static let shopCheckCodes: Set<Int> = [402, 403, 404]
    /// The addresses whose events go through the queue.
    static let paths: Set<String> = ["push", "push/custom", "track/stories", "track/slider", "popup/showed"]
    /// The one address that reads the event's own time.
    static let timedPath = "push/custom"
    /// The one address that reads `source`.
    static let sourcePath = "push"

    // MARK: - One queue per folder

    private final class WeakHost {
        weak var host: EventQueueHost?
        init(_ host: EventQueueHost) { self.host = host }
    }

    private final class WeakQueue {
        weak var queue: EventQueue?
        init(_ queue: EventQueue) { self.queue = queue }
    }

    /// Guards the registry, the hosts of each queue and the events on their way.
    private static let registryLock = NSLock()
    private static var registry: [String: WeakQueue] = [:]
    /// Events on their way, by folder and number, whichever queue sent them.
    private static var onTheirWay: Set<String> = []

    /// The queue of the shop's folder, shared by its instances; `host` becomes the one that sends.
    static func attach(_ host: EventQueueHost, storage: ShopStorage, logger: SdkLogger) -> EventQueue {
        let key = storage.queueDirectory?.standardizedFileURL.path
        registryLock.lock(); defer { registryLock.unlock() }
        let queue: EventQueue
        if let key = key, let existing = registry[key]?.queue {
            queue = existing
        } else {
            queue = EventQueue(key: key, storage: storage, logger: logger)
            if let key = key {
                registry[key] = WeakQueue(queue)
            }
        }
        queue.hosts.removeAll { $0.host == nil }
        queue.hosts.append(WeakHost(host))
        return queue
    }

    /// `host` stops sending (`release()`). The queue's last host gone, it stops: the events stay on
    /// disk for the next launch, and the app's callbacks hear `notInitialized`.
    func detach(_ host: EventQueueHost?) {
        Self.registryLock.lock()
        hosts.removeAll { $0.host == nil || $0.host === host }
        let empty = hosts.isEmpty
        if empty, let key = key, Self.registry[key]?.queue === self {
            Self.registry[key] = nil
        }
        Self.registryLock.unlock()
        if empty {
            work.async { self.stop() }
        }
    }

    /// The host that sends: the last one attached.
    private var owner: EventQueueHost? {
        Self.registryLock.lock(); defer { Self.registryLock.unlock() }
        return hosts.last { $0.host != nil }?.host
    }

    private func isAttached(_ host: EventQueueHost) -> Bool {
        Self.registryLock.lock(); defer { Self.registryLock.unlock() }
        return hosts.contains { $0.host === host }
    }

    private func onTheirWayKey(_ seq: UInt64) -> String? {
        key.map { "\($0)#\(seq)" }
    }

    private static func isOnItsWay(_ key: String) -> Bool {
        registryLock.lock(); defer { registryLock.unlock() }
        return onTheirWay.contains(key)
    }

    private static func markOnItsWay(_ key: String) {
        registryLock.lock()
        onTheirWay.insert(key)
        registryLock.unlock()
    }

    /// The event of `key` got its answer: the folder's queue, if another one sends now, goes on.
    private static func settle(_ key: String, folder: String?, from sender: EventQueue) {
        registryLock.lock()
        onTheirWay.remove(key)
        let current = folder.flatMap { registry[$0]?.queue }
        registryLock.unlock()
        if let current = current, current !== sender {
            current.kick(explicit: false)
        }
    }

    // MARK: - State

    /// The path of the queue's folder: the registry's key.
    let key: String?
    private let storage: ShopStorage
    private let logger: SdkLogger
    private let fileManager = FileManager.default
    /// Everything below happens here, in order; it never waits for the network.
    private let work: DispatchQueue
    /// The app's callbacks, in order, off `work`.
    private let callbacks: DispatchQueue
    /// Under `registryLock`.
    private var hosts: [WeakHost] = []

    private var events: [Event] = []
    private var loaded = false
    private var nextSeq: UInt64 = 1
    /// The event on its way.
    private var inFlight: UInt64?
    private var retry: Cancellable?
    private var retryToken: UUID?
    /// Whether the pause is the server's `Retry-After`: no trigger cuts it short.
    private var retryIsTheServers = false
    /// Failed tries in a row; the pause grows with them.
    private var failures = 0
    /// A check of the shop is on its way after `402`, `403` or `404`.
    private var pausedForCheck = false
    /// No host left.
    private var stopped = false
    /// Bumped by `clear`: an answer to an event sent before changes nothing.
    private var generation = 0
    private var completions: [UInt64: (Outcome) -> Void] = [:]
    /// `flush()` and the background: what they wait for.
    private var passes: [Pass] = []

    /// A wait for the queue to be tried: every event up to `through`.
    private final class Pass {
        let through: UInt64
        let done: () -> Void
        /// While the instance is not usable yet, the wait lasts at most a read timeout.
        var deadline: Cancellable?
        init(through: UInt64, done: @escaping () -> Void) {
            self.through = through
            self.done = done
        }
    }

    /// How long `flush()` waits for the instance to be usable: a request's read timeout.
    static let flushWait = NetworkClient.defaultTimeout

    private struct Event {
        let seq: UInt64
        let path: String
        let body: [String: Any]
        let createdAt: Date
        var attempts: Int
        var shopChecked: Bool
        /// Whether its file was written.
        var stored: Bool
    }

    private init(key: String?, storage: ShopStorage, logger: SdkLogger) {
        self.key = key
        self.storage = storage
        self.logger = logger
        let label = "com.rees46.sdk.queue.\(storage.shopId)"
        self.work = DispatchQueue(label: label, qos: .utility)
        self.callbacks = DispatchQueue(label: label + ".callbacks", qos: .utility)
    }

    // MARK: - Taking events

    /// Takes an event: written to disk in the order of the calls, then sent. `completion` hears once
    /// that it went out, or that it never will. The caller has checked its arguments and the state.
    /// An event the disk refuses is not kept: `unstored` gets its body, stamped, to send once.
    func enqueue(
        path: String,
        body: [String: Any],
        createdAt: Date,
        completion: ((Outcome) -> Void)?,
        unstored: @escaping ([String: Any]) -> Void
    ) {
        work.async {
            self.ensureLoaded()
            let seq = self.nextSeq
            self.nextSeq += 1
            var event = Event(seq: seq, path: path, body: body, createdAt: createdAt, attempts: 0, shopChecked: false, stored: false)
            guard !self.stopped else {
                // Its instance is gone: on disk, it goes on the next launch.
                event.stored = self.write(event)
                completion.map { done in self.callbacks.async { done(.failed(.notInitialized, body: Data())) } }
                return
            }
            // At most `capacity`: the oldest that is not on its way goes.
            while self.events.count >= Self.capacity,
                  let oldest = self.events.firstIndex(where: { $0.seq != self.inFlight }) {
                self.drop(at: oldest, error: .cancelled, reason: "overflow")
            }
            event.stored = self.write(event)
            guard event.stored else {
                // Not accepted: no queue holds it through no network or a restart. It goes once.
                let body = self.stamped(event, host: self.owner)
                self.callbacks.async { unstored(body) }
                return
            }
            self.events.append(event)
            if let completion = completion {
                self.completions[seq] = completion
            }
            self.drain(explicit: false)
        }
    }

    // MARK: - Triggers

    /// Tries to send now. `explicit` — `ready`, the foreground, the background, `flush()` — does not
    /// wait for the pause after a failure; the other triggers do.
    func kick(explicit: Bool) {
        work.async { self.drain(explicit: explicit) }
    }

    /// An `/init` passed: a check of the shop after `402`, `403` or `404` is answered, and the instance
    /// is `ready` with a session.
    func initSucceeded() {
        work.async {
            self.pausedForCheck = false
            self.drain(explicit: true)
        }
    }

    /// Tries every event in the queue now; `done` once each was tried, or none can be: no network, the
    /// server's `Retry-After` not over, released. An instance that is not usable yet — `/init`, a new
    /// session or a check of the shop on its way — is waited for, at most a read timeout.
    func flush(_ done: @escaping () -> Void) {
        work.async {
            self.ensureLoaded()
            self.passes.append(Pass(through: self.events.last?.seq ?? 0, done: done))
            self.drain(explicit: true)
        }
    }

    // MARK: - Clearing

    /// The shop refused: the queue is cleared, and the callbacks hear `error`.
    func clear(error: Rees46.SdkError, reason: String) {
        work.async { self.clearNow(error: error, reason: reason) }
    }

    /// `deleteUserCredentials()`: the events were the deleted customer's. Returns once they are gone.
    func clearSync(error: Rees46.SdkError, reason: String) {
        work.sync { self.clearNow(error: error, reason: reason) }
    }

    private func clearNow(error: Rees46.SdkError, reason: String) {
        generation += 1
        let dropped = events
        events.removeAll()
        loaded = true
        inFlight = nil
        cancelRetry()
        failures = 0
        pausedForCheck = false
        storage.removeQueueDirectory()
        for event in dropped {
            complete(event.seq, .failed(error, body: Data()))
        }
        if !dropped.isEmpty {
            logger.warning(LogCode.queueDropped, "the queue was cleared", ["reason": reason, "count": String(dropped.count)])
        }
        finishPasses()
    }

    private func stop() {
        guard owner == nil else { return }
        stopped = true
        cancelRetry()
        // The events stay on disk; their callbacks belong to the instance that went.
        for event in events {
            complete(event.seq, .failed(.notInitialized, body: Data()))
        }
        events.removeAll()
        finishPasses()
    }

    // MARK: - Sending

    private func drain(explicit: Bool) {
        // A trigger the app or the system gives does not wait for the pause after a failure — but the
        // server's `Retry-After` stands.
        if explicit, !retryIsTheServers {
            cancelRetry()
        }
        // The event on its way goes on when its answer comes.
        guard inFlight == nil else { return }
        guard !stopped, retry == nil, let host = owner else {
            finishPasses()
            return
        }
        guard !pausedForCheck else {
            // The check of the shop is an `/init`: a flush waits for it as for `ready`.
            holdPasses(host)
            return
        }
        ensureLoaded()
        let now = host.queueEnvironment.clock.now()
        while let head = events.first {
            if now.timeIntervalSince(head.createdAt) > Self.lifetime {
                drop(at: 0, error: .timeout, reason: "expired")
                continue
            }
            // Another queue of the shop sent it, or its folder was cleared.
            if head.stored, let file = file(head.seq), !fileManager.fileExists(atPath: file.path) {
                events.removeFirst()
                complete(head.seq, .failed(.cancelled, body: Data()))
                continue
            }
            break
        }
        guard let head = events.first else {
            finishPasses()
            return
        }
        // An event another queue of the shop has on its way waits for its answer.
        if let mark = onTheirWayKey(head.seq), Self.isOnItsWay(mark) {
            finishPasses()
            return
        }
        guard host.queueConnectivity.isOnline else {
            // The network trigger goes on.
            finishPasses()
            return
        }
        switch host.queueGate() {
        case .open:
            send(head, host: host)
        case .wait:
            holdPasses(host)
        case .closed:
            finishPasses()
        case .refused:
            clearNow(error: .shopBlocked, reason: "refused")
        }
    }

    private func send(_ event: Event, host: EventQueueHost) {
        inFlight = event.seq
        let mark = onTheirWayKey(event.seq)
        mark.map(Self.markOnItsWay)
        let generation = self.generation
        let request = NetworkClient.Request(
            method: .post,
            path: event.path,
            body: stamped(event, host: host),
            timeout: nil,
            waitsForNetwork: false
        )
        resolvePasses(before: event.seq)
        let clock = host.queueEnvironment.clock
        let folder = key
        _Concurrency.Task { [weak self] in
            let response = await host.queueSend(request)
            let sentAt = clock.now()
            if let mark = mark, let self = self {
                Self.settle(mark, folder: folder, from: self)
            } else if let mark = mark {
                Self.registryLock.lock()
                Self.onTheirWay.remove(mark)
                Self.registryLock.unlock()
            }
            self?.work.async {
                self?.handle(response, of: event.seq, generation: generation, sentAt: sentAt, sender: host)
            }
        }
    }

    /// The event as it goes: on `push/custom` always a `time` — the app's, or when the event was made —
    /// and nowhere else; on `/push` the stored source, and nowhere else. `sid`, `did` and the other
    /// common fields are the client's, as it sends.
    private func stamped(_ event: Event, host: EventQueueHost?) -> [String: Any] {
        var body = event.body
        if event.path == Self.timedPath {
            if body["time"] == nil {
                body["time"] = Int(event.createdAt.timeIntervalSince1970)
            }
        } else {
            body["time"] = nil
        }
        body["source"] = nil
        if event.path == Self.sourcePath, let source = host?.queueSource() {
            body["source"] = source
        }
        return body
    }

    private func handle(_ response: NetworkClient.Response, of seq: UInt64, generation: Int, sentAt: Date, sender: EventQueueHost) {
        if inFlight == seq {
            inFlight = nil
        }
        // Cleared meanwhile: whatever came back belongs to events that are gone.
        guard generation == self.generation, let index = events.firstIndex(where: { $0.seq == seq }) else {
            drain(explicit: false)
            return
        }
        let event = events[index]
        let random = owner?.queueEnvironment.random ?? { 0.5 }
        switch response.result {
        case .success, .failure(.decoding):
            // Any 2xx: the server has it.
            failures = 0
            events.remove(at: index)
            deleteFile(of: seq)
            complete(seq, .sent(response))
            owner?.queueDelivered(Delivered(path: event.path, response: response, createdAt: event.createdAt, sentAt: sentAt))
            drain(explicit: false)
        case .failure(.cancelled):
            if isAttached(sender) {
                // Cancelled by something else than `release()`: again, after a pause.
                failures += 1
                scheduleRetry(after: RetryPolicy.pause(afterFailures: failures, random: random()))
            } else {
                // Its instance was released: the next owner, if any, sends it.
                drain(explicit: false)
            }
        case .failure(.network):
            if owner?.queueConnectivity.isOnline ?? false {
                // No answer though the device is online: again, after a pause; it does not count.
                failures += 1
                scheduleRetry(after: RetryPolicy.pause(afterFailures: failures, random: random()))
            } else {
                // It waits for the network; it does not count.
                finishPasses()
            }
        case .failure(.timeout):
            failures += 1
            scheduleRetry(after: RetryPolicy.pause(afterFailures: failures, random: random()))
        case .failure(.http(let code, _)) where RetryPolicy.isRetryable(code):
            failures += 1
            events[index].attempts += 1
            if events[index].attempts >= Self.maxAttempts {
                drop(at: index, error: .http(code: code, serverCode: nil), body: response.body, reason: "attempts", status: code)
            } else {
                persist(events[index])
            }
            scheduleRetry(
                after: RetryPolicy.pause(retryAfter: response.retryAfter, afterFailures: failures, random: random()),
                theServers: response.retryAfter != nil
            )
        case .failure(.http(let code, _)) where Self.shopCheckCodes.contains(code):
            guard !event.shopChecked else {
                // The shop passed the check and the event is refused again: a service the shop has not
                // paid for, not the shop. The queue goes on.
                drop(at: index, error: .http(code: code, serverCode: nil), body: response.body, reason: "service_refused", status: code)
                drain(explicit: false)
                return
            }
            events[index].shopChecked = true
            persist(events[index])
            pausedForCheck = true
            if let owner = owner {
                // A flush waits for the check, an `/init`, as for `ready`.
                holdPasses(owner)
            } else {
                finishPasses()
            }
            if !(owner?.queueCheckShop() ?? false) {
                // Asked less than ten minutes ago, and it served: the event goes again.
                pausedForCheck = false
                drain(explicit: false)
            }
        case .failure(.notInitialized), .failure(.shopBlocked):
            // The instance cannot send now: the event stays for the next owner or launch.
            drain(explicit: false)
        case .failure(.http(let code, _)):
            // The request of the SDK is wrong: it would be every time.
            drop(at: index, error: .http(code: code, serverCode: nil), body: response.body, reason: "rejected", status: code)
            drain(explicit: false)
        case .failure(let error):
            // Not sendable: its body is not JSON. It would fail every time.
            drop(at: index, error: error, reason: "rejected")
            drain(explicit: false)
        }
    }

    private func scheduleRetry(after pause: TimeInterval, theServers: Bool = false) {
        cancelRetry()
        let token = UUID()
        retryToken = token
        retryIsTheServers = theServers
        let scheduler = owner?.queueEnvironment.scheduler ?? DispatchScheduler()
        retry = scheduler.schedule(after: pause) { [weak self] in
            self?.work.async {
                guard let self = self, self.retryToken == token else { return }
                self.retry = nil
                self.retryToken = nil
                self.retryIsTheServers = false
                self.drain(explicit: false)
            }
        }
        finishPasses()
    }

    private func cancelRetry() {
        retry?.cancel()
        retry = nil
        retryToken = nil
        retryIsTheServers = false
    }

    // MARK: - Dropping

    private func drop(at index: Int, error: Rees46.SdkError, body: Data = Data(), reason: String, status: Int? = nil) {
        let event = events.remove(at: index)
        deleteFile(of: event.seq)
        complete(event.seq, .failed(error, body: body))
        var context = ["reason": reason, "path": event.path]
        if let status = status {
            context["status"] = String(status)
        }
        logger.warning(LogCode.queueDropped, "an event of \(SdkLogger.requestLine("POST", event.path)) was dropped: \(reason)", context)
    }

    private func complete(_ seq: UInt64, _ outcome: Outcome) {
        guard let completion = completions.removeValue(forKey: seq) else { return }
        callbacks.async { completion(outcome) }
    }

    /// The waits that end once every event up to theirs was tried: those before `seq`.
    private func resolvePasses(before seq: UInt64) {
        let ended = passes.filter { $0.through < seq }
        passes.removeAll { $0.through < seq }
        ended.forEach(end)
    }

    /// The queue cannot send more now: every wait ends.
    private func finishPasses() {
        let ended = passes
        passes.removeAll()
        ended.forEach(end)
    }

    /// The instance is not usable yet: the waits go on until it is — `ready` kicks the queue — or a
    /// read timeout passed.
    private func holdPasses(_ host: EventQueueHost) {
        for pass in passes where pass.deadline == nil {
            pass.deadline = host.queueEnvironment.scheduler.schedule(after: Self.flushWait) { [weak self, weak pass] in
                self?.work.async {
                    guard let self = self, let pass = pass, let index = self.passes.firstIndex(where: { $0 === pass }) else { return }
                    self.passes.remove(at: index)
                    self.end(pass)
                }
            }
        }
    }

    private func end(_ pass: Pass) {
        pass.deadline?.cancel()
        pass.deadline = nil
        callbacks.async(execute: pass.done)
    }

    // MARK: - Disk

    private func file(_ seq: UInt64) -> URL? {
        storage.queueDirectory?.appendingPathComponent(String(format: "%020llu.json", seq))
    }

    /// Reads what an earlier launch left, once: the events in their order, the next number after them.
    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true
        guard let folder = storage.queueDirectory,
              let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return }
        var found: [Event] = []
        var last: UInt64 = 0
        for name in names where name.hasSuffix(".json") {
            guard let seq = UInt64(name.dropLast(5)) else { continue }
            last = max(last, seq)
            let url = folder.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url), let event = Self.decode(data, seq: seq) else {
                try? fileManager.removeItem(at: url)
                logger.warning(LogCode.queueDropped, "an event of the queue could not be read", ["reason": "unreadable"])
                continue
            }
            found.append(event)
        }
        events = found.sorted { $0.seq < $1.seq }
        nextSeq = max(nextSeq, last + 1)
    }

    /// Writes `event` atomically; `false` when the disk refused (`storage_failed`): it still goes now.
    private func write(_ event: Event) -> Bool {
        guard storage.makeQueueDirectory() != nil, let url = file(event.seq) else { return false }
        let record: [String: Any] = [
            "v": 1,
            "path": event.path,
            "body": event.body,
            "created": event.createdAt.timeIntervalSince1970,
            "attempts": event.attempts,
            "checked": event.shopChecked,
        ]
        guard let data = SafeJSON.data(record) else {
            logger.warning(LogCode.storageFailed, "an event of the queue could not be written", ["op": "write_queue_event", "error": "invalid_json"])
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            logger.warning(LogCode.storageFailed, "an event of the queue could not be written", ["op": "write_queue_event", "error": SdkLogger.errorKind(error)])
            return false
        }
    }

    /// Writes the attempts and the check of the shop an event has had.
    private func persist(_ event: Event) {
        guard event.stored else { return }
        _ = write(event)
    }

    private func deleteFile(of seq: UInt64) {
        guard let url = file(seq), fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            logger.warning(LogCode.storageFailed, "an event of the queue could not be removed", ["op": "remove_queue_event", "error": SdkLogger.errorKind(error)])
        }
    }

    private static func decode(_ data: Data, seq: UInt64) -> Event? {
        guard let record = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let path = record["path"] as? String, paths.contains(path),
              let body = record["body"] as? [String: Any],
              let created = record["created"] as? Double, created.isFinite else {
            return nil
        }
        return Event(
            seq: seq,
            path: path,
            body: body,
            createdAt: Date(timeIntervalSince1970: created),
            attempts: record["attempts"] as? Int ?? 0,
            shopChecked: record["checked"] as? Bool ?? false,
            stored: true
        )
    }

    // MARK: - Tests

    /// The events waiting, in order: path and body; for tests.
    var waiting: [(path: String, body: [String: Any])] {
        work.sync { events.map { ($0.path, $0.body) } }
    }

    /// Returns once everything handed to the queue so far was done; for tests.
    func settle() {
        work.sync {}
    }
}
