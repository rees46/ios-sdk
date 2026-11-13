//
//  SdkState.swift
//  REES46
//
//  The state of an instance's initialization (`sdk/core/init.md`), its listeners, and the once-only
//  outcome of `Rees46.initialize`'s completion.
//

import Foundation

extension Rees46 {

    /// Where an instance's initialization is (`sdk/core/init.md`).
    ///
    /// Nested in the facade, like `Rees46.SdkError`, so it does not clash with a type of another module.
    /// On the old core an instance is only ever `initializing` or `ready`, and `notInitialized` once
    /// released.
    public enum SdkState: String, Equatable {
        /// Not started, or released: calls fail with `notInitialized`.
        case notInitialized
        /// `/init` is on its way; calls that return a result wait for it.
        case initializing
        /// The instance has its device id: everything works.
        case ready
        /// `/init` failed for want of a network or on a passing server error, and is repeated after a
        /// pause. With a saved `/init` answer or a stored device id calls work as in `ready`;
        /// otherwise they wait as in `initializing`.
        case retrying
        /// The shop refused the SDK (`402`, `403`, `404` or another `4xx` to `/init`): every call fails
        /// with `shopBlocked` until a later launch's `/init` passes.
        case refused
    }
}

/// An instance's state and the app's listeners of it. A listener hears each change once, on the main
/// thread, in the order the changes happened.
final class InstanceState {

    private final class Listener {
        private let lock = NSLock()
        private var cancelled = false
        private let block: (Rees46.SdkState) -> Void

        init(_ block: @escaping (Rees46.SdkState) -> Void) {
            self.block = block
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }

        func deliver(_ state: Rees46.SdkState) {
            lock.lock()
            let isCancelled = cancelled
            lock.unlock()
            guard !isCancelled else { return }
            block(state)
        }
    }

    private let lock = NSLock()
    private var value: Rees46.SdkState
    private var listeners: [(id: Int, listener: Listener)] = []
    private var nextId = 0

    init(_ initial: Rees46.SdkState = .notInitialized) {
        value = initial
    }

    var current: Rees46.SdkState {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    /// Moves to `state`; `false` when the instance is there already. The change is handed to the main
    /// queue under the lock, so two changes from two threads reach a listener in the order they were
    /// made.
    @discardableResult
    func set(_ state: Rees46.SdkState) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard value != state else { return false }
        value = state
        let current = listeners.map(\.listener)
        if !current.isEmpty {
            DispatchQueue.main.async {
                current.forEach { $0.deliver(state) }
            }
        }
        return true
    }

    /// Calls `listener` on the main thread with the current state, then on every later change, until
    /// the handle is cancelled. The current state is handed to the main queue under the lock that
    /// changes take, so no change between reading the state and subscribing is lost, and none comes
    /// before it.
    func observe(_ listener: @escaping (Rees46.SdkState) -> Void) -> Cancellable {
        let entry = Listener(listener)
        lock.lock()
        nextId += 1
        let id = nextId
        listeners.append((id, entry))
        let current = value
        DispatchQueue.main.async {
            entry.deliver(current)
        }
        lock.unlock()
        return Cancellable { [weak self] in
            entry.cancel()
            guard let self = self else { return }
            self.lock.lock()
            self.listeners.removeAll { $0.id == id }
            self.lock.unlock()
        }
    }
}

/// The completion of `Rees46.initialize`: called once with the outcome of the instance's first
/// initialization, also for the completions of later `initialize` calls for the same shop.
final class InitCompletion {

    private let lock = NSLock()
    /// `nil` until init settles; then the error it ended with, `.none` for none.
    private var outcome: SdkError??
    private var waiting: [(SdkError?) -> Void] = []
    /// The new core calls the app back on the main thread; the old one on the thread init ends on, as
    /// it always has.
    private let onMain: Bool

    init(onMain: Bool) {
        self.onMain = onMain
    }

    /// Calls `completion` once init settles, or now — off the caller's thread — if it has.
    func add(_ completion: ((SdkError?) -> Void)?) {
        guard let completion = completion else { return }
        lock.lock()
        if let outcome = outcome {
            lock.unlock()
            let queue = onMain ? DispatchQueue.main : DispatchQueue.global(qos: .utility)
            queue.async { completion(outcome) }
            return
        }
        waiting.append(completion)
        lock.unlock()
    }

    /// The first call settles the outcome; later ones change nothing.
    func finish(_ error: SdkError?) {
        lock.lock()
        guard outcome == nil else {
            lock.unlock()
            return
        }
        outcome = .some(error)
        let all = waiting
        waiting.removeAll()
        lock.unlock()
        guard !all.isEmpty else { return }
        if onMain {
            DispatchQueue.main.async { all.forEach { $0(error) } }
        } else {
            all.forEach { $0(error) }
        }
    }
}
