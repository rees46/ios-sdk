//
//  CoreV2.swift
//  REES46
//
//  The new core, behind `Rees46Config.coreV2`: the requests of the funnel go through the new client
//  (`NetworkClient`), `/init` is the new core's own (`InitMachine`) and so is the session
//  (`SessionWindow`): a call waits until the instance is usable, at most its own timeout, and goes with
//  the current `sid`.
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

final class CoreV2: Core {

    let kind = CoreKind.v2

    /// The instance's `/init`.
    let machine: InitMachine
    /// The shop's session.
    let session: SessionWindow

    private let client: NetworkClient
    private let connectivity: ConnectivityMonitor?
    private let logger: SdkLogger
    /// Answers come back here, in order, off the cooperative pool: a caller's completion may block.
    private let callbacks: DispatchQueue
    private let lock = NSLock()
    private var released = false

    init(client: NetworkClient, machine: InitMachine, connectivity: ConnectivityMonitor? = nil, label: String, logger: SdkLogger) {
        self.client = client
        self.connectivity = connectivity
        self.machine = machine
        self.session = machine.session
        self.logger = logger
        self.callbacks = DispatchQueue(label: "com.rees46.sdk.core.\(label)", qos: .utility)
    }

    /// Sends `request` once the instance is usable. A call made after `release()` is `notInitialized`;
    /// a shop that refused fails it with `shopBlocked`; one that is not usable within the request's
    /// timeout fails it with `timeout`. An `/init` of the funnel (`sendIDFARequest`) does not wait, and
    /// does not go for a refused shop.
    ///
    /// Every other request checks the session's window (`sdk/core/session.md`): when it ran out,
    /// `/init` goes first and the request waits for it, then goes with the new `sid`, whatever `sid`
    /// its caller put in. A request does not extend the window. Without network it does not wait for
    /// the session: it fails at once, as any request does offline.
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
        // A refused shop sends nothing, its own `/init` of the funnel (`sendIDFARequest`) included: only
        // the machine's `/init` of the next launch asks again.
        if request.isInit, machine.isRefused {
            callbacks.async { completion(Self.legacyResponse(.failure(.shopBlocked), for: request)) }
            return
        }
        let client = self.client
        let machine = self.machine
        let session = self.session
        let logger = self.logger
        let needsSession = !request.isInit && (connectivity?.isOnline ?? true)
        if needsSession, !session.isAlive {
            machine.renewSession()
        }
        var clientRequest = NetworkClient.Request(
            method: request.method,
            path: request.path,
            query: request.query,
            body: request.body,
            timeout: request.timeout,
            waitsForNetwork: request.isInit && request.waitsForNetwork
        )
        let wait = request.isInit ? nil : (request.timeout ?? NetworkClient.defaultTimeout)
        _Concurrency.Task {
            if let wait = wait, let refusal = await machine.awaitUsable(timeout: wait, needsSession: needsSession) {
                if refusal == .cancelled {
                    logger.requestCancelled(request.method.rawValue, request.path)
                }
                callbacks.async { completion(Self.legacyResponse(.failure(refusal), for: request)) }
                return
            }
            if needsSession {
                Self.stampSession(session.sid, on: &clientRequest)
            }
            let response = await client.send(clientRequest)
            callbacks.async { completion(Self.legacyResponse(response, for: request)) }
        }
    }

    /// Puts the current `sid` in place of the one the caller put in when it built the request: the
    /// session may have been renewed while the request waited. A request with the shop's secret keeps
    /// its own identity; without a current `sid` the caller's stays.
    static func stampSession(_ sid: String, on request: inout NetworkClient.Request) {
        guard !sid.isEmpty, request.query["shop_secret"] == nil, request.body["shop_secret"] == nil else { return }
        for key in ["sid", "seance"] {
            if request.query[key] != nil {
                request.query[key] = sid
            }
            if request.body[key] != nil {
                request.body[key] = sid
            }
        }
    }

    /// Sends an event of the queue: the queue decides when, after the instance is usable and its
    /// session alive, so nothing waits here.
    func sendEvent(_ request: NetworkClient.Request) async -> NetworkClient.Response {
        await client.send(request)
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
