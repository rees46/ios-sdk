//
//  PersonalizationSDK+LocalState.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

internal extension PersonalizationSDK {

    /// This shop's stories UI state store. Internal bridge over the concrete SDK, so the stories views
    /// reach the per-shop state through their existing `sdk` reference without widening the public
    /// `PersonalizationSDK` protocol. `nil` only if `sdk` is not the SDK's own implementation.
    var localState: LocalStateRepository? {
        (self as? SimplePersonalizationSDK)?.localStateStore
    }

    /// This shop's attribution store (the source `tracking.setSource(_:)` keeps for 48h). Same bridge
    /// pattern as `localState`, so the tracking services reach the per-shop partition through their
    /// existing `sdk` reference. Conformers that are not the SDK's own implementation — test doubles —
    /// fall back to the shared domain, which is what they used before partitioning.
    var trackingSourceStore: TrackingSourceStore {
        (self as? SimplePersonalizationSDK)?.sourceStore
            ?? TrackingSourceStoreImpl(store: .standard)
    }
}
