//
//  PushEvent.enum.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 The push lifecycle event a host reports through `Rees46.handlePush(_:event:)`.

 `received` tracks delivery (`track/received`); `clicked` tracks the tap (`track/clicked`). Navigation
 (opening the product/category/web the push points to) stays with the host — see `Rees46.handlePush`.

 Mirror of the Android `PushEventType`, renamed on iOS to avoid a clash with the existing
 `PushEventType` (which names the push *content* type: web/category/product/carousel/custom).
 */
public enum PushEvent {
    case received
    case clicked
}
