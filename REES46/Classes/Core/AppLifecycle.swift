//
//  AppLifecycle.swift
//  REES46
//

import UIKit

/// What happens to the app that the core reacts to: sending the queue on the way to the background,
/// checking the session on the way back.
enum AppLifecycleEvent: Equatable {
    case didEnterBackground
    case willEnterForeground
}

/// The app's lifecycle, injectable so tests can move the app to the background and back.
protocol AppLifecycle: AnyObject {
    /// Calls `handler` on every lifecycle event until cancelled.
    func observe(_ handler: @escaping (AppLifecycleEvent) -> Void) -> Cancellable
    /// Whether the app is in the foreground now.
    var isInForeground: Bool { get }
    /// Asks the system for time to finish work after the app went to the background. `expiration`
    /// runs when the time is up; the handle ends the task, once, whichever comes first.
    func beginBackgroundTask(_ name: String, expiration: @escaping () -> Void) -> Cancellable
}

extension AppLifecycle {
    var isInForeground: Bool { true }

    func beginBackgroundTask(_ name: String, expiration: @escaping () -> Void) -> Cancellable {
        Cancellable {}
    }
}

/// The production lifecycle: `UIApplication` notifications.
final class SystemAppLifecycle: AppLifecycle {

    static let shared = SystemAppLifecycle()

    private let lock = NSLock()
    private var foreground = true
    private var tokens: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        tokens = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
                self?.setForeground(false)
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
                self?.setForeground(true)
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
                self?.setForeground(true)
            },
        ]
        // The application's state is read on the main thread only.
        if Thread.isMainThread {
            foreground = UIApplication.shared.applicationState != .background
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.setForeground(UIApplication.shared.applicationState != .background)
            }
        }
    }

    var isInForeground: Bool {
        lock.lock(); defer { lock.unlock() }
        return foreground
    }

    private func setForeground(_ value: Bool) {
        lock.lock()
        foreground = value
        lock.unlock()
    }

    func observe(_ handler: @escaping (AppLifecycleEvent) -> Void) -> Cancellable {
        let center = NotificationCenter.default
        let tokens = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
                handler(.didEnterBackground)
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
                handler(.willEnterForeground)
            },
        ]
        return Cancellable { tokens.forEach(center.removeObserver) }
    }

    func beginBackgroundTask(_ name: String, expiration: @escaping () -> Void) -> Cancellable {
        let task = BackgroundTask()
        let handle = Cancellable { task.end() }
        task.begin(name) {
            expiration()
            handle.cancel()
        }
        return handle
    }

    /// One background task: ended once, from any thread.
    private final class BackgroundTask {
        private let lock = NSLock()
        private var identifier = UIBackgroundTaskIdentifier.invalid
        private var ended = false

        func begin(_ name: String, expiration: @escaping () -> Void) {
            let id = UIApplication.shared.beginBackgroundTask(withName: name, expirationHandler: expiration)
            lock.lock()
            let endNow = ended
            identifier = id
            lock.unlock()
            if endNow {
                end()
            }
        }

        func end() {
            lock.lock()
            ended = true
            let id = identifier
            identifier = .invalid
            lock.unlock()
            if id != .invalid {
                UIApplication.shared.endBackgroundTask(id)
            }
        }
    }
}
