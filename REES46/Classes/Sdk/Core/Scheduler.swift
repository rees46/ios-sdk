//
//  Scheduler.swift
//  REES46
//

import Foundation

/// Runs work later. Injectable, so retry pauses, session windows and queue timers can be tested
/// without waiting real seconds; pairs with `Clock`.
protocol Scheduler: AnyObject {
    /// Runs `work` after `delay` seconds unless the returned handle is cancelled first.
    @discardableResult
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> Cancellable
}

/// The production scheduler: a dispatch queue.
final class DispatchScheduler: Scheduler {

    private let queue: DispatchQueue

    init(queue: DispatchQueue = .global(qos: .utility)) {
        self.queue = queue
    }

    @discardableResult
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> Cancellable {
        let item = DispatchWorkItem(block: work)
        queue.asyncAfter(deadline: .now() + max(0, delay), execute: item)
        return Cancellable { item.cancel() }
    }
}
