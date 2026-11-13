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
/// in flight.
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
    }

    struct Response {
        /// The HTTP status; `nil` when no answer came.
        let status: Int?
        /// The body as it came; empty without one.
        let body: Data
        /// `Retry-After` of the answer in seconds, when it has one.
        let retryAfter: TimeInterval?
        /// The decoded JSON — an empty object for an empty body — or the error.
        let result: Result<Any, Rees46.SdkError>

        static func failure(_ error: Rees46.SdkError) -> Response {
            Response(status: nil, body: Data(), retryAfter: nil, result: .failure(error))
        }
    }

    /// The read timeout of a request that does not ask for its own.
    static let defaultTimeout: TimeInterval = 10
    /// `/init`: the server itself gives up after five seconds.
    static let initTimeout: TimeInterval = 5

    private let session: URLSession
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
        self.session = URLSession(configuration: configuration)
        self.connectivity = connectivity
        self.logger = logger
        self.commonFields = commonFields
    }

    /// The session of the client: a request does not wait for connectivity, and its timeout is set
    /// on the request.
    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = defaultTimeout
        return configuration
    }

    // MARK: - Sending

    func send(_ request: Request) async -> Response {
        guard !released else { return .failure(.cancelled) }
        guard request.waitsForNetwork else {
            guard connectivity.isOnline else {
                logger.warning(LogCode.requestFailed, "no network: \(SdkLogger.requestLine(request.method.rawValue, request.path))",
                               ["method": request.method.rawValue, "path": request.path, "reason": "offline"])
                return .failure(.network)
            }
            return await perform(request)
        }
        while true {
            guard await networkIsBack() else { return .failure(.cancelled) }
            let response = await perform(request)
            // The monitor counts a path it has not reported yet as online: a request sent then may
            // find no network. One that waits for the network goes back to waiting, as the sessions
            // that wait for connectivity do; once the monitor reports a path, a lost request is
            // its failure.
            if case .failure(.network) = response.result, !released, !connectivity.isOnline {
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
        session.invalidateAndCancel()
        for id in Array(waiting.keys) {
            resumeWaiting(id, online: false)
        }
    }

    private func perform(_ request: Request) async -> Response {
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

        let (data, response, error) = await load(urlRequest)
        // A request that `release()` cut short is cancelled, whatever error the session gave it.
        if error != nil, released {
            return .failure(.cancelled)
        }
        guard let http = response as? HTTPURLResponse, error == nil else {
            let failure = error.map(Self.classify) ?? .network
            if failure != .cancelled {
                logger.requestFinished(method, path, status: nil, succeeded: false)
            }
            return .failure(failure)
        }

        let result = Self.classify(status: http.statusCode, body: data)
        // Only the code goes to the log: an error body often repeats the request's data.
        logger.requestFinished(method, path, status: http.statusCode, succeeded: (200..<300).contains(http.statusCode))
        if case .failure(.decoding) = result {
            logger.warning(LogCode.decodingFailed, "the answer to \(SdkLogger.requestLine(method, path)) did not parse", ["path": path])
        }
        return Response(
            status: http.statusCode,
            body: data,
            retryAfter: Self.retryAfter(http.value(forHTTPHeaderField: "Retry-After")),
            result: result
        )
    }

    /// The task is made here, on the actor, so `release()` cannot invalidate the session between the
    /// check above and the task: a task made on an invalidated session raises an exception.
    private func load(_ request: URLRequest) async -> (Data, URLResponse?, Error?) {
        await withCheckedContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                continuation.resume(returning: (data ?? Data(), response, error))
            }.resume()
        }
    }

    private func build(_ request: Request) -> Result<URLRequest, Rees46.SdkError> {
        let fields = commonFields()
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

    /// `true` once the monitor says the device is online; `false` when the client is released first.
    private func networkIsBack() async -> Bool {
        guard !released else { return false }
        guard !connectivity.isOnline else { return true }
        let id = UUID()
        return await withCheckedContinuation { continuation in
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
    }

    private func resumeWaiting(_ id: UUID, online: Bool) {
        guard let entry = waiting.removeValue(forKey: id) else { return }
        entry.subscription?.cancel()
        entry.continuation.resume(returning: online)
    }

    // MARK: - Classification

    /// What an answer means (`sdk/core/network.md`): any `2xx` is a success, an empty body an empty
    /// one; a body that does not parse is `decoding`; anything else is `http` with its code.
    static func classify(status: Int, body: Data) -> Result<Any, Rees46.SdkError> {
        guard (200..<300).contains(status) else {
            // The backend sends no machine code of the error yet (question В5); it will be read here.
            return .failure(.http(code: status, serverCode: nil))
        }
        guard !body.isEmpty else { return .success([String: Any]()) }
        guard let json = try? JSONSerialization.jsonObject(with: body) else { return .failure(.decoding) }
        return .success(json)
    }

    /// A request without an answer: cut by its timeout — mid-body too — is `timeout`; cancelled is
    /// `cancelled`; anything else (no network, no connection, a dropped one) is `network`. Never a
    /// success with part of a body.
    static func classify(_ error: Error) -> Rees46.SdkError {
        guard let urlError = error as? URLError else { return .network }
        switch urlError.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timeout
        default:
            return .network
        }
    }

    /// `Retry-After` in seconds: a number of seconds or an HTTP date.
    static func retryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = TimeInterval(value) {
            return max(0, seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
