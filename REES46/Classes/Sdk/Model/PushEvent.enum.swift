//
//  PushEvent.enum.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 The push lifecycle event a host reports through `Rees46.handlePush(_:event:)` in earlier versions;
 `Rees46.PushEvent` replaces it, with `delivered`, `opened`, `clicked` and `closed`.

 - `delivered` tracks arrival (`track/delivered`) — the raw beacon fired on every push that reaches the
   running app.
 - `received` tracks a background arrival (`track/received`) — the push landed while the app was
   backgrounded, with no interaction. Deprecated (decision 0004): the server counts `track/received` as
   an open, not a delivery. With `Rees46Config.coreV2` it goes as `delivered`.
 - `clicked` tracks the tap (`track/clicked`).

 Navigation (opening the product/category/web the push points to) stays with the host — see
 `Rees46.handlePush`. Superset of the Android `PushEventType` (received/clicked): iOS keeps the separate
 `delivered` beacon its `NotificationService` already emitted. Renamed to `PushEvent` to avoid a clash
 with the existing `PushEventType` (the push *content* type: web/category/product/carousel/custom).
 */
public enum PushEvent {
    case delivered
    @available(*, deprecated, message: "The server counts track/received as an open, not a delivery: use Rees46.handlePush(_:event:) with Rees46.PushEvent.delivered for a push that arrived.")
    case received
    case clicked
}
