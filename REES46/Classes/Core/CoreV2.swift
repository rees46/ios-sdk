//
//  CoreV2.swift
//  REES46
//
//  The new core, behind `Rees46Config.coreV2` (`Rees46.initializeBridge`): the requests of the funnel
//  go through the new client (`NetworkClient`), `/init` is the new core's own (`InitMachine`) and so
//  is the session (`SessionWindow`): a call waits until the instance is usable, at most its own
//  timeout, and goes with the current `sid`.
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
    /// `/init` goes first — the instance stays `ready` — and the request waits for it, then goes with
    /// the new `sid`, whatever `sid` its caller put in. A request does not extend the window. Without network it does not wait for
    /// the session: it fails at once, as any request does offline. One that needs no session — an event
    /// of a push — neither renews nor waits for it.
    func send(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void) {
        let callbacks = self.callbacks
        switch flight(of: request) {
        case .settled(let response):
            callbacks.async { completion(Self.legacyResponse(response, for: request)) }
        case .pending(let fly):
            _Concurrency.Task {
                let response = await fly()
                callbacks.async { completion(Self.legacyResponse(response, for: request)) }
            }
        }
    }

    /// `send` for the methods of the namespaces (`NamespaceRequests`): the same path, answered with the
    /// new core's result, in the caller's task — cancelling the task cancels the request, also while it
    /// waits for the instance to be usable, and it ends as `cancelled`.
    func response(to request: CoreRequest) async -> NetworkClient.Response {
        switch flight(of: request) {
        case .settled(let response):
            return response
        case .pending(let fly):
            return await fly()
        }
    }

    /// A request's way out: settled at once, or the work that waits for the instance and sends it.
    private enum Flight {
        case settled(NetworkClient.Response)
        case pending(() async -> NetworkClient.Response)
    }

    /// What `send` and `response(to:)` do with `request`: the checks and the session's renewal at the
    /// call, the wait and the request in the work it hands back.
    private func flight(of request: CoreRequest) -> Flight {
        lock.lock()
        let isReleased = released
        lock.unlock()
        // A call after `release()` is `notInitialized`; the ones in flight end as `cancelled`.
        guard !isReleased else {
            return .settled(.failure(.notInitialized))
        }
        // A refused shop sends nothing, its own `/init` of the funnel (`sendIDFARequest`) included: only
        // the machine's `/init` of the next launch asks again.
        if request.isInit, machine.isRefused {
            return .settled(.failure(.shopBlocked))
        }
        let client = self.client
        let machine = self.machine
        let session = self.session
        let logger = self.logger
        let needsSession = !request.isInit && request.needsSession && (connectivity?.isOnline ?? true)
        if needsSession, !session.isAlive {
            machine.renewSession()
        }
        let clientRequest = NetworkClient.Request(
            method: request.method,
            path: request.path,
            query: request.query,
            body: request.body,
            timeout: request.timeout,
            waitsForNetwork: request.isInit && request.waitsForNetwork,
            queryLists: request.queryLists
        )
        let wait = request.isInit ? nil : (request.timeout ?? NetworkClient.defaultTimeout)
        return .pending {
            var clientRequest = clientRequest
            if let wait = wait, let refusal = await machine.awaitUsable(timeout: wait, needsSession: needsSession) {
                if refusal == .cancelled {
                    logger.requestCancelled(request.method.rawValue, request.path)
                }
                return .failure(refusal)
            }
            if needsSession {
                Self.stampSession(session.sid, on: &clientRequest)
            }
            if let identity = request.identity {
                // The customer it was made for, checked and taken together after the wait.
                guard let taken = identity() else {
                    logger.requestCancelled(request.method.rawValue, request.path)
                    return .failure(.cancelled)
                }
                clientRequest.identity = taken
            }
            return await client.send(clientRequest)
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
        var error: Rees46.SdkError?
        if case .failure(let failure) = response.result {
            error = failure
        }
        return CoreResponse(status: response.status, body: response.body, result: result, error: error)
    }
}
