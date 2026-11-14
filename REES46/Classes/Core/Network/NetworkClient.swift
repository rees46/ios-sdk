//
//  NetworkClient.swift
//  REES46
//
//  The HTTP client of one SDK instance in the new core (`sdk/core/network.md`).
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

/// One `URLSession` per instance behind an actor. It adds the common fields, gives each request its
/// own timeout, fails a request at once without network, classifies what comes back into
/// `Rees46.SdkError`, and logs method, path and status only. It does not retry: `/init` and the queue
/// decide on retries, and the answer's `Retry-After` reaches them as data. `release()` cancels what is
/// in flight, and so does cancelling the task that waits for an answer.
actor NetworkClient {

    struct Request {
        let method: CoreRequest.Method
        /// Under the API host, without a leading slash.
        let path: String
        var query: [String: String] = [:]
        var body: [String: Any] = [:]
        /// The read timeout of this request; `nil` is `defaultTimeout`, or `initTimeout` for `/init`.
        var timeout: TimeInterval?
        /// Waits for the network instead of failing at once without it.
        var waitsForNetwork = false
        /// The device id and session this request goes with, taken by its sender when it decided to send
        /// it — an event of the queue — instead of the ones stored when the request is built: a
        /// `deleteUserCredentials()` in between does not move it to the next customer's did.
        var identity: CommonFields.Identity?
    }

    struct Response {
        /// The HTTP status; `nil` when no answer came.
        let status: Int?
        /// The body as it came; empty without one.
        let body: Data
        /// `Retry-After` of a `429` or `503` in seconds, when it has a valid one (decision 0002): not
        /// held to the limits of a pause yet — `RetryPolicy` does that.
        let retryAfter: TimeInterval?
        /// The decoded JSON — an empty object for an empty body — or the error.
        let result: Result<Any, Rees46.SdkError>

        static func failure(_ error: Rees46.SdkError) -> Response {
            Response(status: nil, body: Data(), retryAfter: nil, result: .failure(error))
        }
    }

    /// The read timeout of a request that does not ask for its own; the old core uses it too.
    static let defaultTimeout: TimeInterval = 10
    /// `/init`: the server itself gives up after five seconds.
    static let initTimeout: TimeInterval = 5
    /// How long a request that waits for the network waits for the monitor's first path after it
    /// failed for want of a network at cold start.
    static let firstPathWait: TimeInterval = 5

    /// Whether a request that got no answer had reached the server: its headers had started to go
    /// out. Before that a failure is `network` (no network, DNS, a refused connection, a connect that
    /// timed out), after it `timeout`. `nil` when the session gave no metrics for the request: then a
    /// timed-out one is `timeout`, anything else `network`.
    static func reachedServer(_ task: URLSessionTask, _ metrics: URLSessionTaskMetrics?) -> Bool? {
        if let override = reachedServerOverride, let reached = override(task, metrics) {
            return reached
        }
        return requestWentOut(metrics)
    }

    /// The default answer: the task's metrics say a request started; `nil` without metrics.
    static func requestWentOut(_ metrics: URLSessionTaskMetrics?) -> Bool? {
        metrics.map { $0.transactionMetrics.contains { $0.requestStartDate != nil } }
    }

    private static let overrideLock = NSLock()
    private static var overrideValue: ((URLSessionTask, URLSessionTaskMetrics?) -> Bool?)?

    /// Test-only: a URL protocol serves requests without the phases the metrics report, so the stub
    /// server says which requests reached it; `nil` from it falls back to the metrics.
    static var reachedServerOverride: ((URLSessionTask, URLSessionTaskMetrics?) -> Bool?)? {
        get {
            overrideLock.lock(); defer { overrideLock.unlock() }
            return overrideValue
        }
        set {
            overrideLock.lock(); defer { overrideLock.unlock() }
            overrideValue = newValue
        }
    }

    private let sessions: Sessions
    private let baseURL: String
    private let connectivity: ConnectivityMonitor
    private let commonFields: () -> CommonFields
    private let logger: SdkLogger

    private var released = false
    /// Requests waiting for the network, with their subscription to it.
    private var waiting: [UUID: (continuation: CheckedContinuation<Bool, Never>, subscription: Cancellable?)] = [:]

    /// - Parameters:
    ///   - baseURL: `https://<apiDomain>/`.
    ///   - commonFields: read on every request: the device id and the session change.
    init(
        baseURL: String,
        configuration: URLSessionConfiguration = NetworkClient.configuration(),
        connectivity: ConnectivityMonitor,
        logger: SdkLogger,
        commonFields: @escaping () -> CommonFields
    ) {
        self.baseURL = baseURL
        self.sessions = Sessions(configuration: configuration)
        self.connectivity = connectivity
        self.logger = logger
        self.commonFields = commonFields
    }

    deinit {
        sessions.finish()
    }

    /// The session of the client: a request does not wait for connectivity, its timeout is set on
    /// the request, and no cookie goes or is kept (`withoutCookies()`).
    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default.withoutCookies()
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = defaultTimeout
        return configuration
    }

    /// Sends the next requests with the app's configuration (`configureURLSession`, the `urlSession`
    /// it set): its proxy, headers, protocols and TLS settings, never its cookies. A request still fails
    /// at once without network and keeps its own timeout; what the old session carries finishes there.
    func use(_ configuration: URLSessionConfiguration) {
        guard !released else { return }
        sessions.replace(with: configuration)
    }

    // MARK: - Sending

    func send(_ request: Request) async -> Response {
        guard !released, !_Concurrency.Task.isCancelled else { return cancelled(request) }
        guard request.waitsForNetwork else {
            guard connectivity.isOnline else {
                logger.requestOffline(request.method.rawValue, request.path)
                return .failure(.network)
            }
            return await perform(request)
        }
        while true {
            guard await networkIsBack() else { return cancelled(request) }
            let response = await perform(request)
            guard case .failure(.network) = response.result, !released, !_Concurrency.Task.isCancelled else {
                return response
            }
            // Lost for want of a network, a request that waits for it goes back to waiting, as the
            // sessions that wait for connectivity do.
            if !connectivity.isOnline {
                continue
            }
            // At cold start the monitor counts the path it has not reported yet as online, and the
            // request found none: it waits for the first path instead of failing. Once the monitor
            // reports one, a lost request is its failure.
            if !connectivity.hasPath, await firstPathCame() {
                continue
            }
            return response
        }
    }

    /// Stops the client: requests in flight end as `cancelled`, waiting ones too, later ones are not
    /// sent.
    func release() {
        guard !released else { return }
        released = true
        sessions.invalidateAndCancel()
        for id in Array(waiting.keys) {
            resumeWaiting(id, online: false)
        }
    }

    /// A request `release()` ended, before it went out or in flight.
    private func cancelled(_ request: Request) -> Response {
        logger.requestCancelled(request.method.rawValue, request.path)
        return .failure(.cancelled)
    }

    private func perform(_ request: Request) async -> Response {
        // `release()` may have come while the request waited for the network.
        guard !released, !_Concurrency.Task.isCancelled else { return cancelled(request) }
        let method = request.method.rawValue
        let path = request.path
        let urlRequest: URLRequest
        switch build(request) {
        case let .success(built):
            urlRequest = built
        case let .failure(error):
            logger.error(LogCode.requestBuildFailed, "\(SdkLogger.requestLine(method, path)) could not be built", ["method": method, "path": path])
            return .failure(error)
        }

        let loaded = await load(urlRequest)
        let data = loaded.data
        // A request that `release()` or the caller's task cut short is cancelled, whatever error the
        // session gave it.
        if loaded.error != nil, released || _Concurrency.Task.isCancelled {
            return cancelled(request)
        }
        guard let http = loaded.response as? HTTPURLResponse, loaded.error == nil else {
            let failure = loaded.error.map { Self.classify($0, reachedServer: loaded.reachedServer) } ?? .network
            if failure == .cancelled {
                return cancelled(request)
            }
            let offline = failure == .network && !connectivity.isOnline
            logger.requestFinished(method, path, status: nil, succeeded: false, reason: offline ? SdkLogger.offlineReason : nil)
            return .failure(failure)
        }

        let result = Self.classify(status: http.statusCode, body: data, path: path)
        // Only the code goes to the log: an error body often repeats the request's data.
        logger.requestFinished(method, path, status: http.statusCode, succeeded: (200..<300).contains(http.statusCode))
        if case .failure(.decoding) = result {
            logger.warning(LogCode.decodingFailed, "the answer to \(SdkLogger.requestLine(method, path)) did not parse", ["path": path])
        }
        return Response(
            status: http.statusCode,
            body: data,
            retryAfter: Self.retryAfter(http.value(forHTTPHeaderField: "Retry-After"), status: http.statusCode),
            result: result
        )
    }

    /// What one request got.
    private struct Loaded {
        let data: Data
        let response: URLResponse?
        let error: Error?
        /// Whether the request had reached the server when it failed; `nil` without metrics.
        let reachedServer: Bool?

        static let cancelled = Loaded(data: Data(), response: nil, error: URLError(.cancelled), reachedServer: false)
    }

    /// Sends one request. The task is made under the lock that `release()` takes to invalidate the
    /// session, so it is never made on an invalidated session, which raises an exception; cancelling
    /// the caller's task cancels it.
    private func load(_ request: URLRequest) async -> Loaded {
        let sessions = self.sessions
        let handle = TaskHandle()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Loaded, Never>) in
                let made = sessions.dataTask(with: request) { data, response, error, metrics in
                    let reached = handle.task.flatMap { Self.reachedServer($0, metrics) }
                    continuation.resume(returning: Loaded(data: data ?? Data(), response: response, error: error, reachedServer: reached))
                }
                guard let task = made else {
                    continuation.resume(returning: .cancelled)
                    return
                }
                handle.start(task)
            }
        } onCancel: {
            handle.cancel()
        }
    }

    private func build(_ request: Request) -> Result<URLRequest, Rees46.SdkError> {
        var fields = commonFields()
        if let identity = request.identity {
            fields = fields.with(identity)
        }
        var urlRequest: URLRequest
        switch request.method {
        case .get:
            let query = fields.apply(to: request.query, path: request.path)
            guard var components = URLComponents(string: baseURL + request.path) else {
                return .failure(.invalidArgument("the path \(request.path) is not a URL path"))
            }
            components.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
            // URLComponents leaves "+" as it is, and the server reads it as a space: a phone number
            // "+7…" would lose its plus.
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            guard let url = components.url else {
                return .failure(.invalidArgument("the path \(request.path) is not a URL path"))
            }
            urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
        case .post:
            guard let url = URL(string: baseURL + request.path) else {
                return .failure(.invalidArgument("the path \(request.path) is not a URL path"))
            }
            guard let body = SafeJSON.data(fields.apply(to: request.body, path: request.path)) else {
                return .failure(.invalidArgument("the parameters of \(request.path) are not valid JSON"))
            }
            urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = body
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = request.timeout ?? (request.path == "init" ? Self.initTimeout : Self.defaultTimeout)
        return .success(urlRequest)
    }

    // MARK: - Waiting for the network

    /// `true` once the monitor says the device is online; `false` when the client is released or the
    /// caller's task is cancelled first.
    private func networkIsBack() async -> Bool {
        guard !released, !_Concurrency.Task.isCancelled else { return false }
        guard !connectivity.isOnline else { return true }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiting[id] = (continuation, nil)
                let subscription = connectivity.observe { [weak self] online in
                    guard online, let self = self else { return }
                    _Concurrency.Task { await self.resumeWaiting(id, online: true) }
                }
                // The monitor may have answered at once; then the request is no longer waiting.
                if waiting[id] != nil {
                    waiting[id]?.subscription = subscription
                } else {
                    subscription.cancel()
                }
            }
        } onCancel: {
            // Runs on the actor after the request started waiting: the actor is busy until then.
            _Concurrency.Task { await self.resumeWaiting(id, online: false) }
        }
    }

    /// Waits for the monitor's first path, at most `firstPathWait`; `false` when it did not come or the
    /// client was released or the task cancelled meanwhile.
    private func firstPathCame() async -> Bool {
        let deadline = Date().addingTimeInterval(Self.firstPathWait)
        while !connectivity.hasPath {
            guard !released, !_Concurrency.Task.isCancelled, Date() < deadline else { return false }
            try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)
        }
        return !released && !_Concurrency.Task.isCancelled
    }

    private func resumeWaiting(_ id: UUID, online: Bool) {
        guard let entry = waiting.removeValue(forKey: id) else { return }
        entry.subscription?.cancel()
        entry.continuation.resume(returning: online)
    }

    // MARK: - Classification

    /// What an answer means (`sdk/core/network.md`): any `2xx` is a success, an empty body an empty
    /// one — but for `/init`, whose answer is the device id: an empty one is `decoding`; a body that
    /// does not parse is `decoding`; anything else is `http` with its code.
    static func classify(status: Int, body: Data, path: String = "") -> Result<Any, Rees46.SdkError> {
        guard (200..<300).contains(status) else {
            // The backend sends no machine code of the error yet (question В5); it will be read here.
            return .failure(.http(code: status, serverCode: nil))
        }
        guard !body.isEmpty else { return path == "init" ? .failure(.decoding) : .success([String: Any]()) }
        guard let json = try? JSONSerialization.jsonObject(with: body) else { return .failure(.decoding) }
        return .success(json)
    }

    /// A request without an answer (`sdk/core/errors.md`): cancelled is `cancelled`; one that never
    /// reached the server — no network, DNS, a refused connection, a connect that timed out — is
    /// `network`; one that did, and whose answer did not come in time or broke off midway, is
    /// `timeout`. Without the session's metrics (`reachedServer` is `nil`) a request that timed out is
    /// `timeout` and any other failure `network`. Never a success with part of a body.
    static func classify(_ error: Error, reachedServer: Bool?) -> Rees46.SdkError {
        let code = (error as? URLError)?.code
        if code == .cancelled {
            return .cancelled
        }
        guard let reachedServer = reachedServer else {
            return code == .timedOut ? .timeout : .network
        }
        return reachedServer ? .timeout : .network
    }

    /// The statuses whose `Retry-After` the SDK honours (decision 0002).
    static let retryAfterStatuses: Set<Int> = [429, 503]

    /// `Retry-After` of an answer with `status`: only a `429` or `503` has one that counts.
    static func retryAfter(_ value: String?, status: Int, now: Date = Date()) -> TimeInterval? {
        guard retryAfterStatuses.contains(status) else { return nil }
        return retryAfter(value, now: now)
    }

    /// `Retry-After` in seconds: a number of seconds or an HTTP date. A value that is not a finite,
    /// non-negative number of seconds — `inf`, `nan`, `-5`, `1e400` — or not a date is none; a date in
    /// the past is `0`.
    static func retryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = TimeInterval(value) {
            return seconds.isFinite && seconds >= 0 ? seconds : nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        let seconds = date.timeIntervalSince(now)
        return seconds.isFinite ? max(0, seconds) : nil
    }
}

// MARK: - Sessions

/// The client's session and the one the app's configuration replaced last. A task is made and the
/// sessions are invalidated under one lock, so no task is ever made on an invalidated session.
private final class Sessions {

    /// One session with what it reports of its requests.
    private struct Entry {
        let session: URLSession
        let metrics: TaskMetrics
    }

    /// The delegate's queue, serial: a task's metrics and its completion come one after the other.
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "com.rees46.sdk.network-client"
        return queue
    }()
    private let lock = NSLock()
    private var current: Entry
    /// The session the last `replace` let finish what it carried; an older one was let go of then.
    private var previous: Entry?
    private var invalidated = false

    init(configuration: URLSessionConfiguration) {
        current = Self.entry(configuration, queue: queue)
    }

    /// Whatever configuration it is given — the client's, the app's —, the session sends and keeps no
    /// cookies.
    private static func entry(_ configuration: URLSessionConfiguration, queue: OperationQueue) -> Entry {
        let metrics = TaskMetrics()
        let session = URLSession(configuration: configuration.withoutCookies(), delegate: metrics, delegateQueue: queue)
        return Entry(session: session, metrics: metrics)
    }

    /// A task on the current session; `nil` once the sessions are invalidated. `completion` gets the
    /// task's metrics too, `nil` when the session gave none; its entry is gone either way.
    func dataTask(
        with request: URLRequest,
        completion: @escaping (Data?, URLResponse?, Error?, URLSessionTaskMetrics?) -> Void
    ) -> URLSessionDataTask? {
        lock.lock(); defer { lock.unlock() }
        guard !invalidated else { return nil }
        let metrics = current.metrics
        let handle = TaskIdentifier()
        let task = current.session.dataTask(with: request) { data, response, error in
            completion(data, response, error, handle.id.flatMap { metrics.take($0) })
        }
        handle.id = task.taskIdentifier
        return task
    }

    func replace(with configuration: URLSessionConfiguration) {
        let own = (configuration.copy() as? URLSessionConfiguration) ?? configuration
        own.waitsForConnectivity = false
        lock.lock(); defer { lock.unlock() }
        guard !invalidated else { return }
        current.session.finishTasksAndInvalidate()
        previous = current
        current = Self.entry(own, queue: queue)
    }

    /// `release()`: every request in flight ends, no new one is made.
    func invalidateAndCancel() {
        lock.lock(); defer { lock.unlock() }
        guard !invalidated else { return }
        invalidated = true
        current.session.invalidateAndCancel()
        previous?.session.invalidateAndCancel()
    }

    /// The client is gone without `release()`: what is in flight finishes, the sessions let go of
    /// their delegate.
    func finish() {
        lock.lock(); defer { lock.unlock() }
        guard !invalidated else { return }
        invalidated = true
        current.session.finishTasksAndInvalidate()
    }
}

/// The identifier of a task, set once the task is made: its completion reads it.
private final class TaskIdentifier {
    private let lock = NSLock()
    private var value: Int?
    var id: Int? {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}

/// What each request of one session went through, as the session reports it, keyed by the task's
/// identifier, which is unique within its session. An entry leaves when the request's completion takes
/// it; metrics that come after the completion are dropped.
final class TaskMetrics: NSObject, URLSessionTaskDelegate {

    private let lock = NSLock()
    private var byTask: [Int: URLSessionTaskMetrics] = [:]
    /// Tasks whose completion came first: their metrics, when they come, are not kept.
    private var completed: Set<Int> = []

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock(); defer { lock.unlock() }
        let id = task.taskIdentifier
        if completed.remove(id) != nil {
            return
        }
        byTask[id] = metrics
    }

    /// The metrics of task `id`, removed; `nil` when they have not come — and then they never stay.
    func take(_ id: Int) -> URLSessionTaskMetrics? {
        lock.lock(); defer { lock.unlock() }
        if let metrics = byTask.removeValue(forKey: id) {
            return metrics
        }
        // Bounded, should a session never report a finished task's metrics.
        if completed.count >= 256 {
            completed.removeAll()
        }
        completed.insert(id)
        return nil
    }

    /// How many entries it holds; for tests.
    var pending: Int {
        lock.lock(); defer { lock.unlock() }
        return byTask.count + completed.count
    }
}

/// One request's task, for the handler that cancels it when the caller's task is cancelled.
private final class TaskHandle {

    private let lock = NSLock()
    private var current: URLSessionTask?
    private var cancelled = false

    var task: URLSessionTask? {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func start(_ task: URLSessionTask) {
        lock.lock()
        current = task
        let cancelled = self.cancelled
        lock.unlock()
        task.resume()
        if cancelled {
            task.cancel()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = current
        lock.unlock()
        task?.cancel()
    }
}
