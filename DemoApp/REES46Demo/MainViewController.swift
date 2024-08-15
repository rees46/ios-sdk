//
//  ViewController.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import UIKit
import REES46
import AdSupport
import AppTrackingTransparency

class MainViewController: UIViewController, UIScrollViewDelegate {
    
    @IBOutlet private weak var menuButton: UIButton!
    @IBOutlet private weak var searchButton: UIButton!
    @IBOutlet private weak var cartButton: UIButton!
    
    @IBOutlet private weak var fcmTokenLabel: UILabel!
    @IBOutlet private weak var pushTokenLabel: UILabel!
    @IBOutlet private weak var didLabel: UILabel!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var updateDidButton: UIButton!
    @IBOutlet private weak var resetDidButton: UIButton!
    @IBOutlet private weak var showStoriesButton: UIButton!
    
    public var waitIndicator: SdkActivityIndicator!
    
    @IBOutlet private weak var storiesCollectionView: StoriesView!
    public var recommendationsCollectionView = RecommendationsWidgetView()
    public var newArrivalsCollectionView = RecommendationsWidgetView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSdkObservers()
        setupSdkDemoAppViews()
        setupSdkActivityIndicator()
        loadRecommendationsWidget()
        loadNewArrivalsWidget()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        requestTrackingAuthorization()
        super.viewDidAppear(animated)
    }
    
    func addSdkObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadStoriesViewBlock),
            name: globalSDKNotificationNameMainInit, object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadRecommendationsWidget),
            name: globalSDKNotificationNameAdditionalInit, object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadNewArrivalsWidget),
            name: globalSDKNotificationNameAdditionalInit, object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: globalSDKNotificationNameMainInit, object: nil)
        NotificationCenter.default.removeObserver(self, name: globalSDKNotificationNameAdditionalInit, object: nil)
    }
    
    @objc
    private func loadStoriesViewBlock() {
        if let globalSDK = globalSDK {
            storiesCollectionView.configure(
                sdk: globalSDK,
                mainVC: self,
                code: AppEnvironments.storiesCode
            )
        }
    }
    
    @objc
    private func loadRecommendationsWidget() {
        sleep(3)
        if let globalSDKAdditionalInit = globalSDK {
            DispatchQueue.main.async {
                self.recommendationsCollectionView.loadWidget(
                    sdk: globalSDKAdditionalInit,
                    blockId: AppEnvironments.blockId,
                    recommendationId: AppEnvironments.recommendationId
                )
                self.scrollView.addSubview(self.recommendationsCollectionView)
                
                // Recommendation Widget height and position settings
                self.recommendationsCollectionView.heightAnchor.constraint(equalToConstant: 460).isActive = true //height
                self.recommendationsCollectionView.topAnchor.constraint(equalTo: self.storiesCollectionView.bottomAnchor, constant: 10).isActive = true //top
                self.recommendationsCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true //left
                self.recommendationsCollectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true //right
                
                self.didLabel.text = "DID\n\n" + globalSDKAdditionalInit.getDeviceId() //Test delete if needed
            }
        }
    }
    
    @objc
    private func loadNewArrivalsWidget() {
        if let globalSDKAdditionalInit = globalSDK {
            DispatchQueue.main.async {
                self.newArrivalsCollectionView.loadWidget(
                    sdk: globalSDKAdditionalInit,
                    blockId: AppEnvironments.blockId,
                    recommendationId: AppEnvironments.recommendationId
                )
                self.scrollView.addSubview(self.newArrivalsCollectionView)
                
                // Recommendation Widget height and position settings
                self.newArrivalsCollectionView.heightAnchor.constraint(equalToConstant: 460).isActive = true //height
                self.newArrivalsCollectionView.topAnchor.constraint(equalTo: self.recommendationsCollectionView.bottomAnchor, constant: 30).isActive = true //top
                self.newArrivalsCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true //left
                self.newArrivalsCollectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true //right
                
                self.didLabel.text = "DID\n\n" + globalSDKAdditionalInit.getDeviceId()
                // For test delete if needed
            }
        }
    }
    
    @objc
    private func didTapMenu() {
        //
    }
    
    @objc
    private func didTapSearch() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let searchVC = storyboard.instantiateViewController(withIdentifier: "searchVC") as? SearchViewController {
            searchVC.sdk = globalSDK
            self.present(searchVC, animated: true, completion: nil)
        } else {
            print("Unable to instantiate SearchViewController")
        }
    }
    
    @objc
    private func didTapCart() {
        //
    }
    
    @objc
    private func didTapUpdate() {
        setupSdkLabels()
        globalSDK?.resetSdkCache()
        
        if let globalSDK = globalSDK {
            storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: AppEnvironments.storiesCode)
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
    
    @objc
    private func showStories(){
        storiesCollectionView.showStories()
    }
    
    func setupSdkDemoAppViews() {
        navigationController?.navigationBar.isHidden = true
        scrollView.contentSize = CGSize(width: UIScreen.main.bounds.size.width, height: 2000)
        
        menuButton.addTarget(self, action: #selector(didTapMenu), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(didTapSearch), for: .touchUpInside)
        cartButton.addTarget(self, action: #selector(didTapCart), for: .touchUpInside)
        updateDidButton.addTarget(self, action: #selector(didTapUpdate), for: .touchUpInside)
        resetDidButton.addTarget(self, action: #selector(didTapReset), for: .touchUpInside)
        showStoriesButton.addTarget(self, action: #selector(showStories), for: .touchUpInside)
        
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
            
            let deviceId = UserDefaults.standard.string(forKey: "device_id") ?? "No did token"
            self.didLabel.text = "DID\n\n" + deviceId
            
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
    
    //Advertising identifier support
    public func requestTrackingAuthorization() {
        guard #available(iOS 14, *) else { return }
        ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    let idfa = ASIdentifierManager.shared().advertisingIdentifier
                    globalSDK?.sendIDFARequest(idfa: idfa, completion: { initIdfaResult in
                        switch initIdfaResult {
                        case .success:
                            print("\nSDK User granted access to 'ios_advertising_id'\nIDFA:", idfa, "\n")
                        case .failure(_):
                            break
                        }
                    })
                case .denied, .restricted:
                    print("SDK User denied access to 'ios_advertising_id' IDFA\n")
                case .notDetermined:
                    print("SDK User not received an authorization request to 'ios_advertising_id' IDFA\n")
                @unknown default:
                    break
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}


@IBDesignable class DemoShopButton: UIButton {
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
        layer.backgroundColor = UIColor.black.cgColor
        layer.masksToBounds = true
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.white.cgColor
        layer.cornerRadius = 8
        //layer.cornerRadius = frame.size.height / 2
    }
}
