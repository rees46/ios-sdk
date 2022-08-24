//
//  ViewController.swift
//  REES46
//
//  Created by Avsi222 on 08/06/2020.
//  Copyright (c) 2020 Avsi222. All rights reserved.
//

import UIKit
import REES46

class ViewController: UIViewController {
    
    @IBOutlet private weak var fcmTokenLabel: UITextView!
    @IBOutlet private weak var pushTokenLabel: UITextView!
    @IBOutlet private weak var didLabel: UITextView!
    
    @IBOutlet private weak var updateButton: UIButton!
    
//    @IBOutlet private weak var storiesBackView: StoriesCollectionView!
        @IBOutlet private weak var storiesBackView: StoriesView!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateButton.addTarget(self, action: #selector(didTapUpdate), for: .touchUpInside)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc
    func didTapUpdate() {
        pushTokenLabel.text = "PUSHTOKEN = " + pushGlobalToken
        fcmTokenLabel.text = "FCMTOKEN = " + fcmGlobalToken
        didLabel.text = "DID = " + didToken
        if let globalSDK = globalSDK {
            storiesBackView.configure(sdk: globalSDK, mainVC: self)
        }
//        if let globalSDK = globalSDK {
//
////            let storiesSDKView = StoriesView(sdk: globalSDK)
////            storiesBackView.addSubview(storiesSDKView)
//        }
    }
}

