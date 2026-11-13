//
//  CoreV2.swift
//  REES46
//
//  The new core, behind `Rees46Config.coreV2`. Stage 1: the requests of the funnel go through the
//  new client (`NetworkClient`); init, session and queue are still the instance's old ones, so
//  only `/init` may wait for the network, as the old init does.
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

final class CoreV2: Core {

    let kind = CoreKind.v2

    private let client: NetworkClient
    private let logger: SdkLogger
    /// Answers come back here, in order, off the cooperative pool: a caller's completion may block.
    private let callbacks: DispatchQueue
    private let lock = NSLock()
    private var released = false

    init(client: NetworkClient, label: String, logger: SdkLogger) {
        self.client = client
        self.logger = logger
        self.callbacks = DispatchQueue(label: "com.rees46.sdk.core.\(label)", qos: .utility)
    }

    func send(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void) {
        lock.lock()
        let isReleased = released
        lock.unlock()
        let callbacks = self.callbacks
        guard !isReleased else {
            logger.requestCancelled(request.method.rawValue, request.path)
            callbacks.async { completion(Self.legacyResponse(.failure(.cancelled), for: request)) }
            return
        }
        let client = self.client
        let clientRequest = NetworkClient.Request(
            method: request.method,
            path: request.path,
            query: request.query,
            body: request.body,
            timeout: request.timeout,
            waitsForNetwork: request.isInit && request.waitsForNetwork
        )
        _Concurrency.Task {
            let response = await client.send(clientRequest)
            callbacks.async { completion(Self.legacyResponse(response, for: request)) }
        }
    }

    func release() {
        lock.lock()
        released = true
        lock.unlock()
        let client = self.client
        _Concurrency.Task { await client.release() }
    }

    /// The answer as the old methods take it: the old error, with the error body's message for a
    /// `POST`, as the old `postRequest` gave it.
    static func legacyResponse(_ response: NetworkClient.Response, for request: CoreRequest) -> CoreResponse {
        let result = response.result.mapError { error -> SdkError in
            let message = request.method == .post ? SdkError.serverMessage(in: response.body) : nil
            return SdkError.legacy(error, serverMessage: message)
        }
        return CoreResponse(status: response.status, body: response.body, result: result)
    }
}
