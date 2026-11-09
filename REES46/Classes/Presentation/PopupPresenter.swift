//
//  PopupPresenter.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import UIKit

// MARK: - Popup Presenter Service

public class PopupPresenter {
    private weak var sdk: AnyObject? // Use AnyObject to avoid circular dependency
    private var currentPopup: NotificationWidget?
    private var popupQueue: [Popup] = []
    private let serialQueue = DispatchQueue(label: "com.rees46.popup.presenter")
    private var popupShownFlags: [Int: Date] = [:]

    /// Open legacy popups across every SDK instance (main thread). Popups v3 share the modal slot
    /// with them: a v3 modal does not open over a legacy popup and vice versa.
    private(set) static var presentingCount = 0

    /// Whether any SDK instance is showing a legacy popup now.
    static var isAnyPresenting: Bool { presentingCount > 0 }

    public init(sdk: AnyObject) {
        self.sdk = sdk
        // A v3 modal closed: a legacy popup waiting for the slot can show now.
        NotificationCenter.default.addObserver(forName: .personalizationPopupsV3SlotFreed, object: nil, queue: nil) { [weak self] _ in
            self?.resumeQueue()
        }
    }

    /// Shows the next queued popup if nothing occupies the slot.
    private func resumeQueue() {
        serialQueue.async { [weak self] in
            guard let self = self, self.currentPopup == nil, !PopupV3Slots.isModalOpen,
                  let nextPopup = self.popupQueue.first else { return }
            self.popupQueue.removeFirst()
            self.showPopupNow(nextPopup)
        }
    }
    
    // MARK: - Public Interface
    
    /// Main entry point - call this to present any popup
    public func presentPopup(_ popup: Popup) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.currentPopup != nil || PopupV3Slots.isModalOpen {
                // Queue popup if one is already showing (a popups v3 modal included)
                self.popupQueue.append(popup)
            } else {
                self.showPopupNow(popup)
            }
        }
    }
    
    /// Dismiss the current popup and show the next one in queue
    public func dismissCurrentPopup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.currentPopup != nil {
                self.currentPopup = nil
                PopupPresenter.presentingCount = max(0, PopupPresenter.presentingCount - 1)
                NotificationCenter.default.post(name: .personalizationLegacyPopupClosed, object: nil)
            }
            
            // Present next queued popup if any
            self.serialQueue.async {
                if !PopupV3Slots.isModalOpen, let nextPopup = self.popupQueue.first {
                    self.popupQueue.removeFirst()
                    self.showPopupNow(nextPopup)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func showPopupNow(_ popup: Popup) {
        // Check if popup was shown in the last 60 seconds
        if let shownDate = popupShownFlags[popup.id] {
            let timeSinceShown = Date().timeIntervalSince(shownDate)
            if timeSinceShown < 60 {
                return // Popup was already shown, skip
            }
        }
        
        guard let presentingVC = getPresentingViewController(for: popup) else {
            return // No VC available or delegate prevented presentation
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let widget = NotificationWidget(
                parentViewController: presentingVC,
                popup: popup,
                onDismiss: { [weak self] in
                    self?.dismissCurrentPopup()
                }
            )
            // A popup with nothing to draw never calls `onDismiss`: it must not hold the slot.
            if widget.isShowingPopup {
                if self.currentPopup == nil { PopupPresenter.presentingCount += 1 }
                self.currentPopup = widget
            } else {
                self.resumeQueue()
            }
            
            // Store popup shown flag in memory for 60 seconds
            self.popupShownFlags[popup.id] = Date()
            
            // Remove flag after 60 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                self?.popupShownFlags.removeValue(forKey: popup.id)
            }
            
            // Send popup shown event to server
            if let sdk = self.sdk as? PersonalizationSDK {
                sdk.trackPopupShown(popupId: popup.id) { _ in
                    // Handle result (log if needed)
                }
            }
        }
    }
    
    private func getPresentingViewController(for popup: Popup) -> UIViewController? {
        // Fallback chain:
        
        // 1. Check delegate first (if set, delegate has full control)
        if let sdk = sdk as? PersonalizationSDK,
           let delegate = sdk.popupPresentationDelegate {
            return delegate.sdk(sdk, shouldPresentPopup: popup)
        }
        
        // 2. Check if auto-presentation is enabled
        guard let sdk = sdk as? PersonalizationSDK,
              sdk.enableAutoPopupPresentation == true else {
            return nil // Auto-presentation disabled, no delegate = no presentation
        }
        
        // 3. Check parentViewController (backward compatibility)
        if let parentVC = sdk.parentViewController {
            return parentVC
        }
        
        // 4. Auto-discover from window hierarchy (must be on main thread)
        var topVC: UIViewController?
        DispatchQueue.main.sync {
            topVC = getTopViewController()
        }
        return topVC
    }
    
    private func getTopViewController() -> UIViewController? {
        // Get key window's root view controller
        if #available(iOS 13.0, *) {
            // iOS 13+ approach using UIWindowScene
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                  let rootViewController = window.rootViewController else {
                return nil
            }
            return findTopViewController(from: rootViewController)
        } else {
            // iOS 12 and earlier approach using UIApplication.shared.keyWindow
            guard let window = UIApplication.shared.keyWindow,
                  let rootViewController = window.rootViewController else {
                return nil
            }
            return findTopViewController(from: rootViewController)
        }
    }
    
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        // Traverse to find the topmost presented view controller
        if let presented = viewController.presentedViewController {
            return findTopViewController(from: presented)
        }
        
        if let navigationController = viewController as? UINavigationController {
            if let visible = navigationController.visibleViewController {
                return findTopViewController(from: visible)
            }
        }
        
        if let tabBarController = viewController as? UITabBarController {
            if let selected = tabBarController.selectedViewController {
                return findTopViewController(from: selected)
            }
        }
        
        return viewController
    }
}
