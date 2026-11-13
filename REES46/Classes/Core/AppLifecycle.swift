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
}

/// The production lifecycle: `UIApplication` notifications.
final class SystemAppLifecycle: AppLifecycle {

    static let shared = SystemAppLifecycle()

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
}
