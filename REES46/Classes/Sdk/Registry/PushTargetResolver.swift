//
//  PushTargetResolver.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Pure decision behind push routing (R4): which shop a push belongs to.

 The payload's `shop_id` names the target; with no `shop_id`, a single-instance app still works (the
 one live shop is used). A `shop_id` that names no live instance, or an absent `shop_id` while several
 shops are live, resolves to `nil` — the push is dropped rather than delivered to the wrong shop.
 Side-effect-free — mirror of the Android `PushTargetResolver`.
 */
internal enum PushTargetResolver {

    static func resolve(payloadShopId: String?, liveShopIds: Set<String>) -> String? {
        if let payloadShopId = payloadShopId {
            return liveShopIds.contains(payloadShopId) ? payloadShopId : nil
        }
        return liveShopIds.count == 1 ? liveShopIds.first : nil
    }
}
