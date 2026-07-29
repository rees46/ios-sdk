//
//  Cancellable.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Handle for a subscription that must be torn down — e.g. a `SdkRegistry.onNextRegister` callback
 cancelled when the view that registered it detaches, so the callback (and whatever it captures) is
 not leaked.

 Mirror of the Android `Cancellable` fun-interface. Kept `internal` in R1 (the registry is the only
 caller); the public `Rees46.awaitInstance` facade in R3 will re-expose it. `cancel()` is idempotent
 — calling it after the subscription already fired or was cancelled is a no-op.
 */
internal final class Cancellable {

    /// A no-op handle for subscriptions that resolved synchronously and hold nothing.
    static let noop = Cancellable {}

    private let onCancel: () -> Void
    private let lock = NSLock()
    private var cancelled = false

    init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        lock.lock()
        let alreadyCancelled = cancelled
        cancelled = true
        lock.unlock()
        if !alreadyCancelled {
            onCancel()
        }
    }
}
