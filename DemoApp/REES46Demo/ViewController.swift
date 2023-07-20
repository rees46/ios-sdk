//
//  ViewController.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import UIKit
import REES46

class ViewController: UIViewController {
    
    @IBOutlet private weak var fcmTokenLabel: UITextView!
    @IBOutlet private weak var pushTokenLabel: UITextView!
    @IBOutlet private weak var didLabel: UITextView!
    
    @IBOutlet private weak var updateButton: UIButton!
    @IBOutlet private weak var storiesCollectionView: StoriesView!
    //@IBOutlet private weak var sss: Storyv!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateButton.addTarget(self, action: #selector(didTapUpdate), for: .touchUpInside)
        addStoriesObserver()
    }
    
    func addStoriesObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateStories), name: globalSDKNotificationName, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: globalSDKNotificationName, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc
    private func updateStories() {
        if let globalSDK = globalSDK {
            storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "fcaa8d3168ab7d7346e4b4f1a1c92214")
        }
    }
    
    @objc
    private func didTapUpdate() {
        
        //let navVC = NavigationStackController.init(rootViewController: self)
        //let nav = UINavigationController(rootViewController: navVC)
        //self.window?.rootViewController = nav
        //self.navigationController?.pushViewController(nav, animated: true)
        //return
        
        pushTokenLabel.text = "PUSHTOKEN = " + pushGlobalToken
        fcmTokenLabel.text = "FCMTOKEN = " + fcmGlobalToken
        didLabel.text = "DID = " + didToken
        
        globalSDK?.resetCachedWatchedStoriesStates()

        if let globalSDK = globalSDK {
            storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "fcaa8d3168ab7d7346e4b4f1a1c92214")
        }
    }
}


@IBDesignable class UpdateButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        updateButtonCornerRadius()
    }

    @IBInspectable var rounded: Bool = false {
        didSet {
            updateButtonCornerRadius()
        }
    }

    func updateButtonCornerRadius() {
        layer.backgroundColor = UIColor.white.cgColor
        layer.masksToBounds = true
        layer.borderWidth = 1.2
        layer.borderColor = UIColor.systemBlue.cgColor
        layer.cornerRadius = frame.size.height / 2
    }
}
