//
//  LegacyCore.swift
//  REES46
//
//  The request paths of the SDK as they were before the new core, moved here unchanged: the
//  instance's callback sessions, `2xx` but `299` as success, the error body's message as `.custom`
//  for a `POST`, the network monitor asked after a request got no answer.
//

import Foundation

final class LegacyCore: Core {

    let kind = CoreKind.legacy

    private let baseURL: String
    private let stream: String
    private let logger: SdkLogger
    private let connectivity: ConnectivityMonitor
    /// The session most requests go through; the app may swap it (`configureURLSession`).
    private let session: () -> URLSession
    /// The session of requests that fail at once without network instead of waiting for it.
    private let sessionWithoutWaiting: URLSession

    init(
        baseURL: String,
        stream: String,
        logger: SdkLogger,
        connectivity: ConnectivityMonitor,
        session: @escaping () -> URLSession,
        sessionWithoutWaiting: URLSession
    ) {
        self.baseURL = baseURL
        self.stream = stream
        self.logger = logger
        self.connectivity = connectivity
        self.session = session
        self.sessionWithoutWaiting = sessionWithoutWaiting
    }

    private let lock = NSLock()
    private var released = false

    /// Stops the core: later requests are not sent and fail as `notInitialized` does for the old
    /// methods. The old core keeps its sessions — they belong to the instance, and the app may have
    /// handed it one of its own — so what is in flight finishes.
    func release() {
        lock.lock()
        released = true
        lock.unlock()
    }

    /// The old core reads the instance's session on every request: the app's one is already there.
    func use(_ configuration: URLSessionConfiguration) {}

    func send(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void) {
        lock.lock()
        let isReleased = released
        lock.unlock()
        guard !isReleased else {
            DispatchQueue.global(qos: .utility).async {
                completion(CoreResponse(status: nil, body: Data(), result: .failure(.legacy(.notInitialized)), error: .notInitialized))
            }
            return
        }
        switch request.method {
        case .get:
            get(request, completion: completion)
        case .post:
            post(request, completion: completion)
        }
    }

    // MARK: - GET

    private func get(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void) {
        let path = request.path
        var url = URLComponents(string: base(of: request) + path)
        var queryItems = request.query.map { URLQueryItem(name: $0.key, value: $0.value) }
        queryItems.append(URLQueryItem(name: "stream", value: stream))
        url?.queryItems = queryItems

        guard let endUrl = url?.url else {
            logger.error(LogCode.requestBuildFailed, "\(SdkLogger.requestLine("GET", path)) could not be built", ["method": "GET", "path": path])
            completion(CoreResponse(status: nil, body: Data(), result: .failure(.invalidResponse), error: .invalidArgument("the path \(path) is not a URL path")))
            return
        }
        let session = request.waitsForNetwork ? self.session() : sessionWithoutWaiting
        session.postTask(with: urlRequest(for: endUrl, timeout: request.timeout)) { result in
            switch result {
            case .success(let (response, data)):
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                // The error body is not logged: servers repeat the request data in it.
                let succeeded = 200 ..< 300 ~= statusCode
                self.logger.requestFinished("GET", path, status: statusCode, succeeded: succeeded)
                guard succeeded else {
                    completion(CoreResponse(status: statusCode, body: data, result: .failure(.invalidResponse), error: .http(code: statusCode, serverCode: nil)))
                    return
                }
                do {
                    completion(CoreResponse(status: statusCode, body: data, result: .success(try JSONSerialization.jsonObject(with: data))))
                } catch {
                    self.logger.warning(LogCode.decodingFailed, "the answer to \(SdkLogger.requestLine("GET", path)) did not parse", ["path": path])
                    completion(CoreResponse(status: statusCode, body: data, result: .failure(.decodeError), error: .decoding))
                }
            case .failure(let failure):
                self.logger.requestFinished("GET", path, status: nil, succeeded: false, reason: self.failureReason())
                completion(CoreResponse(status: nil, body: Data(), result: .failure(self.transportError()), error: self.transportFailure(failure)))
            }
        }.resume()
    }

    // MARK: - POST

    private func post(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void) {
        let path = request.path
        guard let url = URL(string: base(of: request) + path) else {
            logger.error(LogCode.requestBuildFailed, "\(SdkLogger.requestLine("POST", path)) could not be built", ["method": "POST", "path": path])
            completion(CoreResponse(status: nil, body: Data(), result: .failure(.invalidResponse), error: .invalidArgument("the path \(path) is not a URL path")))
            return
        }
        var requestParams: [String: Any] = ["stream": stream]
        for (key, value) in request.body {
            requestParams[key] = value
        }
        var urlRequest = self.urlRequest(for: url, timeout: request.timeout)
        urlRequest.httpMethod = "POST"
        // The funnel let only JSON through, so the body is always written; the safe writer still
        // keeps a value Swift cannot catch from raising an exception.
        urlRequest.httpBody = SafeJSON.data(requestParams, options: .prettyPrinted)
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")

        session().postTask(with: urlRequest) { result in
            switch result {
            case .success(let (response, data)):
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                // The error body is not logged: servers repeat the request data in it.
                let succeeded = 200 ..< 300 ~= statusCode
                self.logger.requestFinished("POST", path, status: statusCode, succeeded: succeeded)
                guard succeeded else {
                    let error = SdkError.serverMessage(in: data).map { SdkError.custom(error: $0) } ?? .invalidResponse
                    completion(CoreResponse(status: statusCode, body: data, result: .failure(error), error: .http(code: statusCode, serverCode: nil)))
                    return
                }
                let decoded = self.decodePost(data, path: path)
                var error: Rees46.SdkError?
                if case .failure = decoded {
                    error = .decoding
                }
                completion(CoreResponse(status: statusCode, body: data, result: decoded, error: error))
            case .failure(let failure):
                self.logger.requestFinished("POST", path, status: nil, succeeded: false, reason: self.failureReason())
                completion(CoreResponse(status: nil, body: Data(), result: .failure(self.transportError()), error: self.transportFailure(failure)))
            }
        }.resume()
    }

    /// The answer of a `POST`. The events that the server answers with `204` and no body take an empty
    /// one as an empty answer: the events of pushes, `popup/showed` and `track/stories`.
    private func decodePost(_ data: Data, path: String) -> Result<Any, SdkError> {
        if data.isEmpty, path.contains("clicked") || path.contains("closed") || path.contains("received") || path.contains("showed") || path == "track/stories" {
            return .success([String: Any]())
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            logger.warning(LogCode.decodingFailed, "the answer to \(SdkLogger.requestLine("POST", path)) did not parse", ["path": path])
            return .failure(.decodeError)
        }
        guard let object = json as? [String: Any] else {
            logger.warning(LogCode.decodingFailed, "the answer to \(SdkLogger.requestLine("POST", path)) is not a JSON object", ["path": path])
            return .failure(.decodeError)
        }
        return .success(object)
    }

    // MARK: - Helpers

    /// The URL `request`'s path goes under: the API host, or the request's own (`CoreRequest.host`).
    private func base(of request: CoreRequest) -> String {
        request.host.map { "https://\($0)/" } ?? baseURL
    }

    /// A request with the call's own timeout. The session is shared: a call that swapped in a session
    /// with its own timeout changed it for every call in flight on the session queue. It neither sends
    /// nor stores cookies, whatever the session — the app may have set one of its own (`urlSession`).
    private func urlRequest(for url: URL, timeout: TimeInterval?) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout ?? NetworkClient.defaultTimeout
        request.httpShouldHandleCookies = false
        return request
    }

    /// A request that got no answer: offline, or the connection failed or timed out.
    private func transportError() -> SdkError {
        connectivity.isOnline ? .invalidResponse : .networkOfflineError
    }

    /// The same failure as the new core names it: `network` offline or when no connection was made,
    /// `timeout` when the request timed out.
    private func transportFailure(_ error: Error) -> Rees46.SdkError {
        guard connectivity.isOnline else { return .network }
        return (error as? URLError)?.code == .timedOut ? .timeout : .network
    }

    /// `context.reason` of a request that got no answer: `offline` when the device has no network.
    private func failureReason() -> String? {
        connectivity.isOnline ? nil : SdkLogger.offlineReason
    }

    /// The configuration of the old sessions. Waiting for connectivity, a request starts its timeout
    /// once the network is back. No cookie goes or is kept (`withoutCookies()`).
    static func sessionConfiguration(waitsForConnectivity: Bool) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default.withoutCookies()
        configuration.waitsForConnectivity = waitsForConnectivity
        configuration.shouldUseExtendedBackgroundIdleMode = waitsForConnectivity
        return configuration
    }
}
