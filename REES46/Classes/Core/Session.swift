//
//  Session.swift
//  REES46
//
//  The session of the new core (`sdk/core/session.md`, decision 0001): the server's `sid` and its
//  two-hour window.
//

import Foundation

/// The session of one shop on the new core.
///
/// - The `sid` is the server's: the `seance` of the last `/init` answer. The core never makes one up.
///   An install of an older SDK keeps the `sid` it made while that window lives: `/init` carries it
///   once, and the server's answer replaces it.
/// - The window is two hours without an event of the queue or an `/init`; only they extend it.
/// - The `sid` and the time of the last event live in the shop's storage, so a restart inside the
///   window goes on with the same session.
/// - Listeners hear every new `sid`, on the main thread, in order.
final class SessionWindow {

    /// Two hours without an event or `/init`.
    static let length: TimeInterval = 2 * 60 * 60

    private let identity: UserIdentityRepository
    private let clock: Clock
    private let lock = NSLock()
    private let listeners = SessionListeners()

    init(identity: UserIdentityRepository, clock: Clock) {
        self.identity = identity
        self.clock = clock
    }

    /// The current `sid`; empty without one. It may belong to a window that has run out: a request
    /// that needs a fresh one waits for `/init`.
    var sid: String {
        lock.lock(); defer { lock.unlock() }
        return identity.seance ?? ""
    }

    /// Whether the window is open: the last event or `/init` was less than two hours ago.
    var isAlive: Bool {
        lock.lock(); defer { lock.unlock() }
        return isAliveLocked(clock.now())
    }

    /// The `sid` `/init` carries: the current one while its window is open, none otherwise.
    var sidForInit: String? {
        liveSid
    }

    /// `/init` answered: its `seance` is the `sid` from now on, and the window opens again. An answer
    /// without one leaves a session without a `sid` that lives out its window — no `/init` again
    /// before it ends. Listeners hear a new `sid`.
    func adopt(_ seance: String) {
        lock.lock(); defer { lock.unlock() }
        let previous = identity.seance ?? ""
        if seance != previous {
            identity.seance = seance.isEmpty ? nil : seance
            if !seance.isEmpty {
                listeners.notify(seance)
            }
        }
        identity.seanceLastActTime = clock.now()
    }

    /// The `sid` of the open window; `nil` without one or once the window ended.
    var liveSid: String? {
        lock.lock(); defer { lock.unlock() }
        let sid = identity.seance ?? ""
        return !sid.isEmpty && isAliveLocked(clock.now()) ? sid : nil
    }

    /// An event of the queue went out: the window opens again.
    func touch() {
        lock.lock(); defer { lock.unlock() }
        identity.seanceLastActTime = clock.now()
    }

    /// Forgets the session: the next `/init` goes without one (`needReInitialization`).
    func forget() {
        lock.lock(); defer { lock.unlock() }
        identity.seance = nil
        identity.seanceLastActTime = nil
    }

    /// Calls `listener` on the main thread with every new `sid` until the handle is cancelled.
    func observe(_ listener: @escaping (String) -> Void) -> Cancellable {
        listeners.add(listener)
    }

    private func isAliveLocked(_ now: Date) -> Bool {
        guard let last = identity.seanceLastActTime else { return false }
        return now.timeIntervalSince(last) < Self.length
    }
}

/// Listeners of the session: each new `sid` goes to the main queue as it is told, so listeners hear
/// the changes in the order they were made.
final class SessionListeners {

    private final class Listener {
        private let lock = NSLock()
        private var cancelled = false
        private let block: (String) -> Void

        init(_ block: @escaping (String) -> Void) {
            self.block = block
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }

        func deliver(_ sid: String) {
            lock.lock()
            let isCancelled = cancelled
            lock.unlock()
            guard !isCancelled else { return }
            block(sid)
        }
    }

    private let lock = NSLock()
    private var listeners: [(id: Int, listener: Listener)] = []
    private var nextId = 0

    func add(_ block: @escaping (String) -> Void) -> Cancellable {
        let entry = Listener(block)
        lock.lock()
        nextId += 1
        let id = nextId
        listeners.append((id, entry))
        lock.unlock()
        return Cancellable { [weak self] in
            entry.cancel()
            guard let self = self else { return }
            self.lock.lock()
            self.listeners.removeAll { $0.id == id }
            self.lock.unlock()
        }
    }

    func notify(_ sid: String) {
        lock.lock()
        let current = listeners.map(\.listener)
        if !current.isEmpty {
            DispatchQueue.main.async {
                current.forEach { $0.deliver(sid) }
            }
        }
        lock.unlock()
    }
}
