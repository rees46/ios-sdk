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
}
