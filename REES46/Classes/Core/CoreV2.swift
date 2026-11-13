//
//  CoreV2.swift
//  REES46
//
//  The new core, behind `Rees46Config.coreV2`: the requests of the funnel go through the new client
//  (`NetworkClient`), and `/init` is the new core's own (`InitMachine`): a call waits until the
//  instance is usable, at most its own timeout. Session and queue are still the instance's old ones.
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

final class CoreV2: Core {

    let kind = CoreKind.v2

    /// The instance's `/init`.
    let machine: InitMachine

    private let client: NetworkClient
    private let logger: SdkLogger
    /// Answers come back here, in order, off the cooperative pool: a caller's completion may block.
    private let callbacks: DispatchQueue
    private let lock = NSLock()
    private var released = false

    init(client: NetworkClient, machine: InitMachine, label: String, logger: SdkLogger) {
        self.client = client
        self.machine = machine
        self.logger = logger
        self.callbacks = DispatchQueue(label: "com.rees46.sdk.core.\(label)", qos: .utility)
    }

    /// Sends `request` once the instance is usable. A call made after `release()` is `notInitialized`;
    /// a shop that refused fails it with `shopBlocked`; one that is not usable within the request's
    /// timeout fails it with `timeout`. An `/init` of the funnel (`sendIDFARequest`) does not wait.
    func send(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void) {
        lock.lock()
        let isReleased = released
        lock.unlock()
        let callbacks = self.callbacks
        // A call after `release()` is `notInitialized`; the ones in flight end as `cancelled`.
        guard !isReleased else {
            callbacks.async { completion(Self.legacyResponse(.failure(.notInitialized), for: request)) }
            return
        }
        let client = self.client
        let machine = self.machine
        let logger = self.logger
        let clientRequest = NetworkClient.Request(
            method: request.method,
            path: request.path,
            query: request.query,
            body: request.body,
            timeout: request.timeout,
            waitsForNetwork: request.isInit && request.waitsForNetwork
        )
        let wait = request.isInit ? nil : (request.timeout ?? NetworkClient.defaultTimeout)
        _Concurrency.Task {
            if let wait = wait, let refusal = await machine.awaitUsable(timeout: wait) {
                if refusal == .cancelled {
                    logger.requestCancelled(request.method.rawValue, request.path)
                }
                callbacks.async { completion(Self.legacyResponse(.failure(refusal), for: request)) }
                return
            }
            let response = await client.send(clientRequest)
            callbacks.async { completion(Self.legacyResponse(response, for: request)) }
        }
    }

    func use(_ configuration: URLSessionConfiguration) {
        let client = self.client
        _Concurrency.Task { await client.use(configuration) }
    }

    /// Asks the shop through `/init` whether it still serves the SDK, at most once in ten minutes.
    @discardableResult
    func checkShop() -> Bool {
        machine.checkShop()
    }

    func release() {
        lock.lock()
        released = true
        lock.unlock()
        machine.release()
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
