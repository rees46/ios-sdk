//
//  NamespaceRequests.swift
//  REES46
//
//  The one way the methods of the namespaces (`sdk.<namespace>.<method>`, all but `tracking`) reach the
//  API: a request of the new core with its value or a `Rees46.SdkError` (`sdk/core/errors.md`), and the
//  pair the contract gives every method (`sdk/contract/README.md`, "Результат и ошибки") — a
//  `completion` called once on the main thread, and an `async throws` form.
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

/// The namespaces' requests of one instance.
///
/// The namespaces run on the new core only, the bridges' (`Rees46.initializeBridge`). On an instance of
/// the old core every method ends as `notInitialized`, sends nothing and logs `core_flag_mismatch`, as on
/// Android; on a conformer of `PersonalizationSDK` other than the SDK's own it ends the same way and logs
/// `not_implemented`. On the new core a request waits for the instance to be usable, at most its timeout,
/// and goes with the current device id and session; nothing repeats it (`sdk/core/network.md`).
/// `release()` ends the calls on their way as `cancelled`, later ones as `notInitialized`.
struct NamespaceRequests {

    private weak var instance: SimplePersonalizationSDK?
    /// Whether it was made for the SDK's own instance: once that is gone, a call is `notInitialized`.
    private let isTheSdks: Bool

    init(_ sdk: PersonalizationSDK) {
        instance = sdk as? SimplePersonalizationSDK
        isTheSdks = instance != nil
    }

    /// The value of the method `name` (`cart.get`, what the log calls it) or its error. `make` builds the
    /// request once the instance takes the call; it throws `Rees46.SdkError.invalidArgument` for an
    /// argument the contract refuses, and then nothing is sent. Cancelling the task cancels the call.
    func result<Value>(_ name: String, _ make: () throws -> ApiRequest<Value>) async -> Result<Value, Rees46.SdkError> {
        // `usesCoreV2` is what makes the core a `CoreV2` (`makeCore`).
        guard let instance = Self.onTheNewCore(instance, isTheSdks: isTheSdks, call: name),
              let core = instance.core as? CoreV2 else {
            return .failure(.notInitialized)
        }
        let request: ApiRequest<Value>
        do {
            request = try make()
        } catch {
            let refusal = error as? Rees46.SdkError ?? .invalidArgument(String(describing: error))
            instance.logger.warning(LogCode.invalidArgument, "\(name): \(refusal.message)", ["call": name])
            return .failure(refusal)
        }
        var coreRequest = request.coreRequest
        if request.host == .app {
            coreRequest.host = instance.config.appDomain
        }
        let response = await core.response(to: coreRequest)
        return Self.value(of: response, for: request, call: name, logger: instance.logger)
    }

    /// `instance` when the method `name` may run on it: the SDK's own, on the new core. Otherwise `nil`
    /// — the method ends as `notInitialized` — and the log says why: `not_implemented` for a conformer of
    /// `owner` other than the SDK's own (`isTheSdks` `false`), `core_flag_mismatch` on the old core;
    /// nothing for the SDK's instance that is gone.
    static func onTheNewCore(
        _ instance: SimplePersonalizationSDK?,
        isTheSdks: Bool,
        call name: String,
        owner: String = "PersonalizationSDK"
    ) -> SimplePersonalizationSDK? {
        guard let instance = instance else {
            if !isTheSdks {
                SdkLogger.process.error(LogCode.notImplemented, "\(name) is not implemented by this \(owner)", ["call": name])
            }
            return nil
        }
        guard instance.usesCoreV2 else {
            instance.logger.warning(
                LogCode.coreFlagMismatch,
                "\(name) runs on the new core only: start the shop with Rees46.initializeBridge",
                ["call": name]
            )
            return nil
        }
        return instance
    }

    /// `result` for a method's `completion`: called exactly once, on the main thread.
    func call<Value>(
        _ name: String,
        completion: @escaping (Result<Value, Rees46.SdkError>) -> Void,
        _ make: @escaping () throws -> ApiRequest<Value>
    ) {
        _Concurrency.Task {
            let result = await self.result(name, make)
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// `result` for a method's `async` form: the value, or the `Rees46.SdkError` thrown. Cancelling the
    /// caller's task ends the call as `cancelled`, also while it waits for the instance.
    func value<Value>(_ name: String, _ make: () throws -> ApiRequest<Value>) async throws -> Value {
        try await result(name, make).get()
    }

    /// The method's value of what the core got. Any `2xx` is a success, but one whose body says
    /// `{"status": "error"}`: that is `decoding`, as is a body that does not read as the method's model.
    /// The log has the call, the method and the path, never the body: an error's text may repeat what
    /// the request carried.
    static func value<Value>(
        of response: NetworkClient.Response,
        for request: ApiRequest<Value>,
        call name: String,
        logger: SdkLogger
    ) -> Result<Value, Rees46.SdkError> {
        let json: Any
        switch response.result {
        case .failure(let error):
            return .failure(error)
        case .success(let value):
            json = value
        }
        let line = SdkLogger.requestLine(request.method.rawValue, request.path)
        let context = ["call": name, "method": request.method.rawValue, "path": request.path]
        if let object = json as? [String: Any], object["status"] as? String == "error" {
            logger.warning(LogCode.decodingFailed, "the answer to \(line) is an error with a 2xx status", context)
            return .failure(.decoding)
        }
        do {
            return .success(try request.decode(response.body))
        } catch {
            logger.warning(LogCode.decodingFailed, "the answer to \(line) does not read as \(name)'s result", context)
            return .failure(.decoding)
        }
    }
}
