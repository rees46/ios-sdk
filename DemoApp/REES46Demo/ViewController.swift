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
    
    public var recommendationsCollectionView = RecommendationsWidgetView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSdkObservers()
    }
    
    func addSdkObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(loadStoriesViewBlock),
                                               name: globalSDKNotificationName, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadRecommendationsWidget),
                                               name: globalSDKNotificationName, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self,name: globalSDKNotificationName, object: nil)
    }
    
    @objc
    private func loadStoriesViewBlock() {
        if let globalSDK = globalSDK {
            storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "fcaa8d3168ab7d7346e4b4f1a1c92214")
            
            //Recommendation Widget loading if need manually after full Sdk Initialization
            //self.loadRecommendationsWidget()
        }
    }
    
    @objc private func loadRecommendationsWidget() {
        if let globalSDK = globalSDK {
            
            DispatchQueue.main.async {
                self.recommendationsCollectionView.loadWidget(sdk: globalSDK, blockId: "bc1f41f40bb4f92a705ec9d5ec2ada42")
                //self.recommendationsCollectionView.loadWidget(sdk: globalSDK, blockId: "a043dbc2f852ffe18861a2cdfc364ef2")
                
                
                self.view.addSubview(self.recommendationsCollectionView)
                
                // Recommendation Widget height and position settings
                self.recommendationsCollectionView.heightAnchor.constraint(equalToConstant: 460).isActive = true //height
                self.recommendationsCollectionView.topAnchor.constraint(equalTo: self.storiesCollectionView.bottomAnchor, constant: 20).isActive = true //top
                self.recommendationsCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true //left
                self.recommendationsCollectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true //right
                
                if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
                    self.recommendationsCollectionView.topAnchor.constraint(equalTo: self.storiesCollectionView.bottomAnchor, constant: -25).isActive = true // old devices position fix
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc
    private func didTapUpdate() {
        pushTokenLabel.text = "PUSHTOKEN = " + pushGlobalToken
        fcmTokenLabel.text = "FCMTOKEN = " + fcmGlobalToken
        didLabel.text = "DID = " + didToken
        
        globalSDK?.resetSdkCache()

        if let globalSDK = globalSDK {
            storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "fcaa8d3168ab7d7346e4b4f1a1c92214")
        }
    }
    
    func setupSdkButtonView() {
        //updateButton.addTarget(self, action: #selector(didTapUpdate), for: .touchUpInside)
        //fontInterPreload()
    }
    
    func fontInterPreload() {
        fcmTokenLabel.font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
        pushTokenLabel .font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
        didLabel.font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
    }
}


@IBDesignable class sdkUpdateTokenButton: UIButton {
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
