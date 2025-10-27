//
//  PopupPresentationDelegate.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import UIKit

// MARK: - Popup Presentation Delegate Protocol

public protocol PopupPresentationDelegate: AnyObject {
    /// Called when SDK has a popup to present
    /// Return presenting UIViewController to allow SDK to present, or nil to prevent presentation
    func sdk(_ sdk: PersonalizationSDK, shouldPresentPopup popup: Popup) -> UIViewController?
}
