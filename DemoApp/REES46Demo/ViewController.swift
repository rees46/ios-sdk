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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateButton.addTarget(self, action: #selector(didTapUpdate), for: .touchUpInside)
        fontInterPreload()
        addStoriesObserver()
    }
    
    func addStoriesObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(loadStoriesViewBlock), name: globalSDKNotificationName, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: globalSDKNotificationName, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc
    private func loadStoriesViewBlock() {
        if let globalSDK = globalSDK {
            storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "fcaa8d3168ab7d7346e4b4f1a1c92214")
        }
    }
    
    @objc
    private func didTapUpdate() {
        pushTokenLabel.text = "PUSHTOKEN = " + pushGlobalToken
        fcmTokenLabel.text = "FCMTOKEN = " + fcmGlobalToken
        didLabel.text = "DID = " + didToken
        
        globalSDK?.resetCachedSlidesStates()

        if let globalSDK = globalSDK {
            storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "fcaa8d3168ab7d7346e4b4f1a1c92214")
        }
    }
    
    func fontInterPreload() {
        fcmTokenLabel.font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
        pushTokenLabel .font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
        didLabel.font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
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
        layer.borderWidth = 1.4
        layer.borderColor = UIColor.systemBlue.cgColor
        layer.cornerRadius = frame.size.height / 2
    }
}
