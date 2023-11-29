//
//  ViewController.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import UIKit
import REES46

class ViewController: UIViewController, UIScrollViewDelegate {
    
    @IBOutlet private weak var fcmTokenLabel: UILabel!
    @IBOutlet private weak var pushTokenLabel: UILabel!
    @IBOutlet private weak var didLabel: UILabel!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var updateDidButton: UIButton!
    @IBOutlet private weak var resetDidButton: UIButton!
    public var waitIndicator: SdkActivityIndicator!
    
    @IBOutlet private weak var storiesCollectionView: StoriesView!
    public var recommendationsCollectionView = RecommendationsWidgetView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSdkObservers()
        setupSdkDemoAppViews()
        setupSdkActivityIndicator()
    }
    
    func addSdkObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(loadStoriesViewBlock),
                                               name: globalSDKNotificationName, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadRecommendationsWidget),
                                               name: globalSDKNotificationName, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: globalSDKNotificationName, object: nil)
    }
    
    @objc
    private func loadStoriesViewBlock() {
        if let globalSDK = globalSDK {
            storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "fcaa8d3168ab7d7346e4b4f1a1c92214")
            
            //Recommendation Widget loading if need manually after Sdk full initialization
            //self.loadRecommendationsWidget()
        }
    }
    
    @objc private func loadRecommendationsWidget() {
        sleep(3)
        if let globalSDK = globalSDK {
            
            DispatchQueue.main.async {
                self.recommendationsCollectionView.loadWidget(sdk: globalSDK, blockId: "bc1f41f40bb4f92a705ec9d5ec2ada42")
                self.view.addSubview(self.recommendationsCollectionView)
                
                // Recommendation Widget height and position settings
                self.recommendationsCollectionView.heightAnchor.constraint(equalToConstant: 460).isActive = true //height
                self.recommendationsCollectionView.topAnchor.constraint(equalTo: self.storiesCollectionView.bottomAnchor, constant: -25).isActive = true //top
                self.recommendationsCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true //left
                self.recommendationsCollectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true //right
            }
        }
    }
    
    @objc
    private func didTapUpdate() {
        setupSdkLabels()
        globalSDK?.resetSdkCache()
        
        if let globalSDK = globalSDK {
            storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "fcaa8d3168ab7d7346e4b4f1a1c92214")
        }
    }
    
    @objc
    private func didTapReset() {
        self.waitIndicator.startAnimating()
        
        let sdkBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier
        let appBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier //Bundle.main.bundleIdentifier
        try? InitService.deleteKeychainDidToken(identifier: sdkBundleId!, instanceKeychainService: appBundleId!)
        sleep(3)
        
        globalSDK?.resetSdkCache()
        globalSDK?.deleteUserCredentials()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.setupSdkLabels()
            self.waitIndicator.stopAnimating()
        }
    }
    
    func setupSdkDemoAppViews() {
        navigationController?.navigationBar.isHidden = true
        scrollView.contentSize = CGSize(width: UIScreen.main.bounds.size.width, height: 1400)

        updateDidButton.addTarget(self, action: #selector(didTapUpdate), for: .touchUpInside)
        resetDidButton.addTarget(self, action: #selector(didTapReset), for: .touchUpInside)
        fontInterPreload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.setupSdkLabels()
        }
    }
    
    func setupSdkLabels() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if pushGlobalToken == "" {
                pushGlobalToken = UserDefaults.standard.string(forKey: "pushGlobalToken") ?? "No push token"
            }
            
            if fcmGlobalToken == "" {
                fcmGlobalToken = UserDefaults.standard.string(forKey: "fcmGlobalToken") ?? "No Firebase token"
            }
            
            let did = UserDefaults.standard.string(forKey: "device_id") ?? "No did token"
            self.didLabel.text = "DID\n\n" + did
            
            self.pushTokenLabel.text = "PUSHTOKEN\n\n" + pushGlobalToken
            self.fcmTokenLabel.text = "FCMTOKEN\n\n" + fcmGlobalToken
        }
    }
    
    func setupSdkActivityIndicator() {
        self.waitIndicator = SdkActivityIndicator(frame: CGRect(x: 0, y: 0, width: 76, height: 76))
        self.waitIndicator.indicatorColor = UIColor.sdkDefaultGreenColor
        self.view.addSubview(self.waitIndicator)
        self.waitIndicator.center = self.view.center
        self.waitIndicator.hideIndicatorWhenStopped = true
    }
    
    func fontInterPreload() {
        fcmTokenLabel.font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
        pushTokenLabel .font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
        didLabel.font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
    }
    
    override func viewDidLayoutSubviews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.systemGreen.cgColor
        layer.cornerRadius = frame.size.height / 2
    }
}
