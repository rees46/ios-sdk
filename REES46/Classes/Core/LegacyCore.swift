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

    /// The old core keeps its sessions: they belong to the instance, and the app may have handed it
    /// one of its own.
    func release() {}

    func send(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void) {
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
        var url = URLComponents(string: baseURL + path)
        var queryItems = request.query.map { URLQueryItem(name: $0.key, value: $0.value) }
        queryItems.append(URLQueryItem(name: "stream", value: stream))
        url?.queryItems = queryItems

        guard let endUrl = url?.url else {
            logger.error(LogCode.requestBuildFailed, "\(SdkLogger.requestLine("GET", path)) could not be built", ["method": "GET", "path": path])
            completion(CoreResponse(status: nil, body: Data(), result: .failure(.invalidResponse)))
            return
        }
        let session = request.waitsForNetwork ? self.session() : sessionWithoutWaiting
        session.postTask(with: urlRequest(for: endUrl, timeout: request.timeout)) { result in
            switch result {
            case .success(let (response, data)):
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                // The error body is not logged: servers repeat the request data in it.
                let succeeded = 200 ..< 299 ~= statusCode
                self.logger.requestFinished("GET", path, status: statusCode, succeeded: succeeded)
                guard succeeded else {
                    completion(CoreResponse(status: statusCode, body: data, result: .failure(.invalidResponse)))
                    return
                }
                do {
                    completion(CoreResponse(status: statusCode, body: data, result: .success(try JSONSerialization.jsonObject(with: data))))
                } catch {
                    self.logger.warning(LogCode.decodingFailed, "the answer to \(SdkLogger.requestLine("GET", path)) did not parse", ["path": path])
                    completion(CoreResponse(status: statusCode, body: data, result: .failure(.decodeError)))
                }
            case .failure:
                self.logger.requestFinished("GET", path, status: nil, succeeded: false, reason: self.failureReason())
                completion(CoreResponse(status: nil, body: Data(), result: .failure(self.transportError())))
            }
        }.resume()
    }

    // MARK: - POST

    private func post(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void) {
        let path = request.path
        guard let url = URL(string: baseURL + path) else {
            logger.error(LogCode.requestBuildFailed, "\(SdkLogger.requestLine("POST", path)) could not be built", ["method": "POST", "path": path])
            completion(CoreResponse(status: nil, body: Data(), result: .failure(.invalidResponse)))
            return
        }
        var requestParams: [String: Any] = ["stream": stream]
        for (key, value) in request.body {
            requestParams[key] = value
        }
        var urlRequest = self.urlRequest(for: url, timeout: request.timeout)
        urlRequest.httpMethod = "POST"
        // The funnel checked the body; a value that is not JSON would raise an exception Swift
        // cannot catch.
        guard let body = SafeJSON.data(requestParams, options: .prettyPrinted) else {
            completion(CoreResponse(status: nil, body: Data(), result: .failure(.custom(error: "\(path): the request parameters are not valid JSON"))))
            return
        }
        urlRequest.httpBody = body
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")

        session().postTask(with: urlRequest) { result in
            switch result {
            case .success(let (response, data)):
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                // The error body is not logged: servers repeat the request data in it.
                let succeeded = 200 ..< 299 ~= statusCode
                self.logger.requestFinished("POST", path, status: statusCode, succeeded: succeeded)
                guard succeeded else {
                    let error = SdkError.serverMessage(in: data).map { SdkError.custom(error: $0) } ?? .invalidResponse
                    completion(CoreResponse(status: statusCode, body: data, result: .failure(error)))
                    return
                }
                completion(CoreResponse(status: statusCode, body: data, result: self.decodePost(data, path: path)))
            case .failure:
                self.logger.requestFinished("POST", path, status: nil, succeeded: false, reason: self.failureReason())
                completion(CoreResponse(status: nil, body: Data(), result: .failure(self.transportError())))
            }
        }.resume()
    }

    private func decodePost(_ data: Data, path: String) -> Result<Any, SdkError> {
        if data.isEmpty, path.contains("clicked") || path.contains("closed") || path.contains("received") || path.contains("showed") {
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

    /// A request with the call's own timeout. The session is shared: a call that swapped in a session
    /// with its own timeout changed it for every call in flight on the session queue.
    private func urlRequest(for url: URL, timeout: TimeInterval?) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout ?? SimplePersonalizationSDK.defaultRequestTimeout
        return request
    }

    /// A request that got no answer: offline, or the connection failed or timed out.
    private func transportError() -> SdkError {
        connectivity.isOnline ? .invalidResponse : .networkOfflineError
    }

    /// `context.reason` of a request that got no answer: `offline` when the device has no network.
    private func failureReason() -> String? {
        connectivity.isOnline ? nil : SdkLogger.offlineReason
    }

    /// The configuration of the old sessions. Waiting for connectivity, a request starts its timeout
    /// once the network is back.
    static func sessionConfiguration(waitsForConnectivity: Bool) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = waitsForConnectivity
        configuration.shouldUseExtendedBackgroundIdleMode = waitsForConnectivity
        return configuration
    }
}
