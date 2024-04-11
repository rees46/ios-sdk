//
//  ViewController.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2024. All rights reserved.
//

import UIKit
import REES46
import AdSupport
import AppTrackingTransparency
import SafariServices
import BackgroundTasks

@available(iOS 13.0, *)
class MainViewController: UIViewController, UIScrollViewDelegate, NetworkStatusObserver {
    
    @IBOutlet private weak var menuButton: UIButton!
    @IBOutlet private weak var searchButton: UIButton!
    @IBOutlet private weak var cartButton: UIButton!
    
    @IBOutlet private weak var didLabel: UILabel!
    @IBOutlet private weak var pushTokenLabel: UILabel!
    @IBOutlet private weak var fcmTokenLabel: UILabel!
    @IBOutlet private weak var idfaLabel: UILabel!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var updateDidButton: UIButton!
    @IBOutlet private weak var resetDidButton: UIButton!
    
    @IBOutlet private var headerSection: UIView!
    
    private var sideMenuViewController: ShopSideMenuViewController!
    private var sideMenuShadowView: UIView!
    private var sideMenuRevealWidth: CGFloat = 350
    private let paddingForRotation: CGFloat = 150
    private var isExpanded: Bool = false
    private var draggingIsEnabled: Bool = false
    private var panBaseLocation: CGFloat = 120.0
    
    private var sideMenuTrailingConstraint: NSLayoutConstraint!

    private var revealSideMenuOnTop: Bool = true
    
    var gestureEnabled: Bool = true
    
    public var waitIndicator: SdkActivityIndicator!
    
    @IBOutlet private weak var storiesCollectionView: StoriesView!
    public var recommendationsCollectionView = RecommendationsWidgetView()
    public var newArrivalsCollectionView = RecommendationsWidgetView()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.removeObserver(self, name: .init(rawValue: "restartApplication"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restartApplication), name: .init(rawValue: "restartApplication"), object: nil)
        
       // runOnce()
        
//        if UserDefaults.standard.object(forKey: "run_once_key_april7") == nil {
//            UserDefaults.standard.set(true, forKey: "run_once_key_april7")
//            let sdkBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier
//            let appBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier //Bundle.main.bundleIdentifier
//            try? InitService.deleteKeychainDidToken(identifier: sdkBundleId!, instanceKeychainService: appBundleId!)
//            sleep(2)
//            
//            globalSDK?.resetSdkCache()
//            globalSDK?.deleteUserCredentials()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
//                //self.setupSdkLabels()
//               // self.waitIndicator.stopAnimating()
//                self.restartApplication()
//                
//            }
//        } else {
//            addSdkObservers()
//            setupSdkDemoAppViews()
//            setupSdkActivityIndicator()
//            
//           // DispatchQueue.onceTechService(token: "keychainDidUpdate") {
//               // UserDefaults.standard.set(successInitDeviceId, forKey: "device_id")
//            //}
//            
//            
//            if #available(iOS 13.0, *) {
//                BGTaskScheduler.shared.register(
//                    forTaskWithIdentifier: "r46.example.train",
//                    using: DispatchQueue.global()
//                ) { task in
//                    self.scheduleMLTrain()
//                }
//            } else {
//                // TODO iOS12
//            }
//            //return true
//            
//            self.setNavBarAppearance(tintColor: .white, barColor: UIColor(#colorLiteral(red: 0.737254902, green: 0.1294117647, blue: 0.2941176471, alpha: 1)))
//
//            self.sideMenuShadowView = UIView(frame: self.view.bounds)
//            self.sideMenuShadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//            self.sideMenuShadowView.backgroundColor = .black
//            self.sideMenuShadowView.alpha = 0.0
//            if #available(iOS 14.0, *) {
//                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(TapGestureRecognizer))
//                tapGestureRecognizer.numberOfTapsRequired = 1
//                tapGestureRecognizer.delegate = self
//                self.sideMenuShadowView.addGestureRecognizer(tapGestureRecognizer)
//            } else {
//                // TODO iOS12
//            }
//            if self.revealSideMenuOnTop {
//                view.insertSubview(self.sideMenuShadowView, at: 1)
//            }
//
//            if #available(iOS 14.0, *) {
//                let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
//                self.sideMenuViewController = storyboard.instantiateViewController(withIdentifier: "SideMenuID") as? SideMenuViewController
//                self.sideMenuViewController.defaultHighlightedCell = 0
//                self.sideMenuViewController.delegate = self
//                view.insertSubview(self.sideMenuViewController!.view, at: self.revealSideMenuOnTop ? 2 : 0)
//                addChild(self.sideMenuViewController!)
//                self.sideMenuViewController!.didMove(toParent: self)
//            } else {
//                // TODO iOS12
//            }
//
//            self.sideMenuViewController.view.translatesAutoresizingMaskIntoConstraints = false
//
//            if self.revealSideMenuOnTop {
//                self.sideMenuTrailingConstraint = self.sideMenuViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -self.sideMenuRevealWidth - self.paddingForRotation)
//                self.sideMenuTrailingConstraint.isActive = true
//            }
//            NSLayoutConstraint.activate([
//                self.sideMenuViewController.view.widthAnchor.constraint(equalToConstant: self.sideMenuRevealWidth),
//                self.sideMenuViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//                self.sideMenuViewController.view.topAnchor.constraint(equalTo: view.topAnchor)
//            ])
//
//            if #available(iOS 14.0, *) {
//                let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
//                panGestureRecognizer.delegate = self
//                view.addGestureRecognizer(panGestureRecognizer)
//                
//                //showViewController(viewController: UINavigationController.self, storyboardId: "HomeNavID")
//                showViewController(viewController: UINavigationController.self, storyboardId: "HomeNavID")
//            } else {
//                // TODO iOS12
//            }
//        }
        
        addSdkObservers()
        
        if #available(iOS 14.0, *) {
            self.setupSdkDemoAppViews()
            //setupSdkDemoAppViews()
        } else {
            // TODO iOS12
        }
        
        setupSdkActivityIndicator()
        
       // DispatchQueue.onceTechService(token: "keychainDidUpdate") {
           // UserDefaults.standard.set(successInitDeviceId, forKey: "device_id")
        //}
        
        
//        if #available(iOS 13.0, *) {
//            BGTaskScheduler.shared.register(
//                forTaskWithIdentifier: "r46.example.train",
//                using: DispatchQueue.global()
//            ) { task in
//                self.scheduleMLTrain()
//            }
//        } else {
//            // TODO iOS12
//        }
        
        //self.setNavBarAppearance(tintColor: .white, barColor: UIColor(#colorLiteral(red: 0.737254902, green: 0.1294117647, blue: 0.2941176471, alpha: 1)))

        self.sideMenuShadowView = UIView(frame: self.view.bounds)
        self.sideMenuShadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sideMenuShadowView.backgroundColor = .black
        self.sideMenuShadowView.alpha = 0.0
        
        if #available(iOS 14.0, *) {
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(TapGestureRecognizer))
            tapGestureRecognizer.numberOfTapsRequired = 1
            tapGestureRecognizer.delegate = self
            self.sideMenuShadowView.addGestureRecognizer(tapGestureRecognizer)
        } else {
            // TODO iOS12
        }
        if self.revealSideMenuOnTop {
            view.insertSubview(self.sideMenuShadowView, at: 1)
        }

        if #available(iOS 14.0, *) {
            let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
            self.sideMenuViewController = storyboard.instantiateViewController(withIdentifier: "SideMenuID") as? ShopSideMenuViewController
            self.sideMenuViewController.defaultHighlightedCell = 1
            self.sideMenuViewController.delegate = self
            //self.sideMenuViewController.modalPresentationStyle = .fullScreen
            view.insertSubview(self.sideMenuViewController!.view, at: self.revealSideMenuOnTop ? 2 : 0)
            addChild(self.sideMenuViewController!)
            self.sideMenuViewController!.didMove(toParent: self)
        } else {
            // TODO iOS12
        }

        self.sideMenuViewController.view.translatesAutoresizingMaskIntoConstraints = false

        if self.revealSideMenuOnTop {
            self.sideMenuTrailingConstraint = self.sideMenuViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -self.sideMenuRevealWidth - self.paddingForRotation)
            self.sideMenuTrailingConstraint.isActive = true
        }
        NSLayoutConstraint.activate([
            self.sideMenuViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            self.sideMenuViewController.view.widthAnchor.constraint(equalTo: view.widthAnchor),
            self.sideMenuViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if #available(iOS 14.0, *) {
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
            panGestureRecognizer.delegate = self
            view.addGestureRecognizer(panGestureRecognizer)
            
            showViewController(viewController: UINavigationController.self, storyboardId: "HomeNavID")
        } else {
            // TODO iOS12
        }
    }
    
    func runOnce() {
        if UserDefaults.standard.object(forKey: "run_once_key8") == nil {
            UserDefaults.standard.set(true, forKey: "run_once_key8")
            let sdkBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier
            let appBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier //Bundle.main.bundleIdentifier
            try? InitService.deleteKeychainDidToken(identifier: sdkBundleId!, instanceKeychainService: appBundleId!)
            sleep(2)
            
            globalSDK?.resetSdkCache()
            globalSDK?.deleteUserCredentials()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.setupSdkLabels()
                self.waitIndicator.stopAnimating()
                self.restartApplication()
                
            }
        } else {
        }
    }
    
//    func formattedDateString(format: String? = "MMM d, h:mm a") -> String {
//        let dateFormatter = DateFormatter()
//        dateFormatter.locale = Locale(identifier: "en_AU")
//        dateFormatter.timeZone = TimeZone(abbreviation: "Australia/Sydney");        dateFormatter.amSymbol = "AM"
//        dateFormatter.pmSymbol = "PM"
//        dateFormatter.calendar = Calendar(identifier: .gregorian);        dateFormatter.dateFormat = format
//        return dateFormatter.string(from: self)
//       
//    }
    
    @objc 
    func restartApplication () {
        if UserDefaults.standard.object(forKey: "run_once_key_april9") == nil {
            UserDefaults.standard.set(true, forKey: "run_once_key_april9")
            let sdkBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier
            let appBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier //Bundle.main.bundleIdentifier
            try? InitService.deleteKeychainDidToken(identifier: sdkBundleId!, instanceKeychainService: appBundleId!)
            sleep(2)
            
            globalSDK?.resetSdkCache()
            globalSDK?.deleteUserCredentials()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                //self.setupSdkLabels()
               // self.waitIndicator.stopAnimating()
                self.restartS()
                
            }
        }
    }
    
    private func restartS() {
        let viewController = MainViewController()
        let navCtrl = UINavigationController(rootViewController: viewController)

        guard
            let window = UIApplication.shared.keyWindow,
            let rootViewController = window.rootViewController

        else {
            return
        }

        navCtrl.view.frame = rootViewController.view.frame
        navCtrl.view.layoutIfNeeded()
        navCtrl.modalPresentationStyle = .fullScreen

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = navCtrl
        })
    }
    
    @available(iOS 13.0, *)
    private func scheduleMLTrain() {
        do {
            let request = BGProcessingTaskRequest(identifier: "r46.example.train")
            request.requiresExternalPower = false
            request.requiresNetworkConnectivity = true
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print(error)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       // startObserving()
        ConnectAbilityManager.shared.startMonitoring()
    }
        
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
     //   stopObserving()
    }
    
    func didChangeConnectionStatus(_ status: REES46.NetworkConnectionStatus) {
        DispatchQueue.main.async {
            switch status {
            case .Online: break
                //self.statusLabel.text = "Online"
                //self.statusLabel.backgroundColor = .systemGreen
            case .Offline: break
                //self.statusLabel.text = "Offline"
                //self.statusLabel.backgroundColor = .systemRed
            }
        }
    }
    
    func didChangeConnectionType(_ type: NetworkConnectionType?) {
           DispatchQueue.main.async {
               guard let connectionType = type else {
                   return
               }
               
               switch connectionType {
               case .cellular(_): break
                   
               case .wifi: break
                   
               case .ethernet: break
                   
               case .notdetected: break
                   
               }
           }
       }
    
    func addSdkObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(loadStoriesViewBlock),
                                               name: globalSDKNotificationNameMainInit, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadRecommendationsWidget),
                                               name: globalSDKNotificationNameAdditionalInit, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadNewArrivalsWidget),
                                               name: globalSDKNotificationNameAdditionalInit, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: globalSDKNotificationNameMainInit, object: nil)
        NotificationCenter.default.removeObserver(self, name: globalSDKNotificationNameAdditionalInit, object: nil)
    }
    
    @objc private func loadStoriesViewBlock() {
        
        if let globalSDK = globalSDK {
           
        storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "be7fd883efcc4518b08cda32bb836306")
            
       //    storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "8e073a72b527adc33241b3da0c981855")
        }
    }
    
    @objc private func loadRecommendationsWidget() {
        sleep(3)
        if let globalSDKAdditionalInit = globalSDKAdditionalInit {
            DispatchQueue.main.async {
                self.recommendationsCollectionView.loadWidget(sdk: globalSDKAdditionalInit, blockId: "bc1f41f40bb4f92a705ec9d5ec2ada42")
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
    
    @objc private func loadNewArrivalsWidget() {
        if let globalSDKAdditionalInit = globalSDKAdditionalInit {
            DispatchQueue.main.async {
                self.newArrivalsCollectionView.loadWidget(sdk: globalSDKAdditionalInit, blockId: "a043dbc2f852ffe18861a2cdfc364ef2")
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
    
    @available(iOS 14.0, *)
    @objc private func didTapMenu() {
//        self.sideMenuState(expanded: self.isExpanded ? false : true)
        //self.view.backgroundColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        
        //self.setNavBarAppearance(tintColor: .white, barColor: UIColor(#colorLiteral(red: 0.737254902, green: 0.1294117647, blue: 0.2941176471, alpha: 1)))
        //self.sideMenuState(expanded: self.isExpanded ? false : true)
        
        
//        self.sideMenuShadowView = UIView(frame: self.view.bounds)
//        self.sideMenuShadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        self.sideMenuShadowView.backgroundColor = .red
//        self.sideMenuShadowView.alpha = 0.0
//        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(TapGestureRecognizer))
//        tapGestureRecognizer.numberOfTapsRequired = 1
//        tapGestureRecognizer.delegate = self
//        self.sideMenuShadowView.addGestureRecognizer(tapGestureRecognizer)
//        if self.revealSideMenuOnTop {
//            view.insertSubview(self.sideMenuShadowView, at: 2)
//        }
//
//        
//        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
//        self.sideMenuViewController = storyboard.instantiateViewController(withIdentifier: "SideMenuID") as? SideMenuViewController
//        self.sideMenuViewController.defaultHighlightedCell = 0
//        self.sideMenuViewController.delegate = self
//        view.insertSubview(self.sideMenuViewController!.view, at: self.revealSideMenuOnTop ? 2 : 0)
//        addChild(self.sideMenuViewController!)
//        self.sideMenuViewController!.didMove(toParent: self)
//        
//        self.view!.insertSubview(self.sideMenuViewController.view, at: 0)
//
//        self.sideMenuViewController.view.translatesAutoresizingMaskIntoConstraints = false
//
//        if self.revealSideMenuOnTop {
//            self.sideMenuTrailingConstraint = self.sideMenuViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -self.sideMenuRevealWidth - self.paddingForRotation)
//            self.sideMenuTrailingConstraint.isActive = true
//        }
//        NSLayoutConstraint.activate([
//            self.sideMenuViewController.view.widthAnchor.constraint(equalToConstant: self.sideMenuRevealWidth),
//            self.sideMenuViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            self.sideMenuViewController.view.topAnchor.constraint(equalTo: view.topAnchor)
//        ])
//
//        if #available(iOS 14.0, *) {
//            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
//            panGestureRecognizer.delegate = self
//            view.addGestureRecognizer(panGestureRecognizer)
//
//            showViewController(viewController: UINavigationController.self, storyboardId: "HomeNavID")
//        } else {
//            // TODO iOS12
//        }
        
        self.sideMenuState(expanded: self.isExpanded ? false : true)
    }
    
    @objc private func didTapSearch() {
        startBlankSearch()
    }
    
    func startBlankSearch() {
        globalSDK?.searchBlank { searchResponse in
            switch searchResponse {
            case let .success(response):
                
                var suggestArray = [String]()
                for item in response.suggests {
                    let product = item.name
                    suggestArray.append(product)
                }
                
                var lastQueriesArray = [String]()
                for item in response.lastQueries {
                    let product = item.name
                    lastQueriesArray.append(product)
                }
                
                var productsRecentlyViewedArray = [String]()
                for item in response.products {
                    let productId = item.id
                    let product = item.name
                    let price = item.priceFormatted
                    let img = item.imageUrl
                    let description = "^" + productId + "^" + "!" + product + "!" + "\n" + "|" + price + "|" + "[" + img + "]"
                    productsRecentlyViewedArray.append(description)
                }
                
                DispatchQueue.main.async {
                    let sdkSearchWidget = SearchWidget()
                    sdkSearchWidget.setCategoriesSuggests(value: [])
                    sdkSearchWidget.setRequestHistories(value: productsRecentlyViewedArray)
                    sdkSearchWidget.setSearchSuggest(value: lastQueriesArray)
                    
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let searchVC = storyboard.instantiateViewController(withIdentifier: "searchVC") as! SearchViewController
                    searchVC.modalPresentationStyle = .fullScreen
                    searchVC.sdk = globalSDK
                    //searchVC.suggestsCategories = suggestArray
                    searchVC.lastQueriesHistories = productsRecentlyViewedArray
                    searchVC.recommendQueries = lastQueriesArray
                    self.present(searchVC, animated: true, completion: nil)
                }
                
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    DispatchQueue.main.async {
                        self.openSearchAnyway()
                    }
                    print("Error:", customError)
                default:
                    DispatchQueue.main.async {
                        self.openSearchAnyway()
                    }
                    print("Error:", error.description)
                }
            }
        }
    }
    
    private func openSearchAnyway() {
        
        let sdkSearchWidget = SearchWidget()
        sdkSearchWidget.setCategoriesSuggests(value: [])
        sdkSearchWidget.setRequestHistories(value: [])
        sdkSearchWidget.setSearchSuggest(value: [])
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let searchVC = storyboard.instantiateViewController(withIdentifier: "searchVC") as! SearchViewController
        searchVC.modalPresentationStyle = .fullScreen
        searchVC.sdk = globalSDK
        searchVC.suggestsCategories = []
        searchVC.lastQueriesHistories = []
        
        self.present(searchVC, animated: true, completion: nil)
    }
    
    @objc private func didTapCart() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let searchVC = storyboard.instantiateViewController(withIdentifier: "searchVC") as! SearchViewController
        searchVC.modalPresentationStyle = .fullScreen
        searchVC.sdk = globalSDK
        searchVC.suggestsCategories = []
        searchVC.lastQueriesHistories = []
        
        self.present(searchVC, animated: true, completion: nil)
    }
    
    @objc private func didTapUpdate() {
        setupSdkLabels()
        globalSDK?.resetSdkCache()
        
        if let globalSDK = globalSDK {
           storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "be7fd883efcc4518b08cda32bb836306")
            
       //  storiesCollectionView.configure(sdk: globalSDK, mainVC: self, code: "8e073a72b527adc33241b3da0c981855")
        }
    }
    
    @objc private func didTapReset() {
        self.waitIndicator.startAnimating()
        
        let sdkBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier
        let appBundleId = Bundle(for: REES46.StoriesView.self).bundleIdentifier //Bundle.main.bundleIdentifier
        try? InitService.deleteKeychainDidToken(identifier: sdkBundleId!, instanceKeychainService: appBundleId!)
        sleep(2)
        
        globalSDK?.resetSdkCache()
        globalSDK?.deleteUserCredentials()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.setupSdkLabels()
            self.waitIndicator.stopAnimating()    
        }
    }
    
    @available(iOS 14.0, *)
    func setupSdkDemoAppViews() {
        navigationController?.navigationBar.isHidden = true
        scrollView.contentSize = CGSize(width: UIScreen.main.bounds.size.width, height: 2100)

        menuButton.addTarget(self, action: #selector(didTapMenu), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(didTapSearch), for: .touchUpInside)
        cartButton.addTarget(self, action: #selector(didTapCart), for: .touchUpInside)
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
            
            let deviceId = UserDefaults.standard.string(forKey: "device_id") ?? "No did token"
            self.didLabel.text = "DID\n\n" + deviceId
            
            self.pushTokenLabel.text = "PUSHTOKEN\n\n" + pushGlobalToken
            self.fcmTokenLabel.text = "FCMTOKEN\n\n" + fcmGlobalToken
            
            let advId = UserDefaults.standard.string(forKey: "IDFA") ?? "IDFA not determined"
            self.idfaLabel.text = "IDFA TOKEN\n\n" + advId
        }
    }
    
    func setupSdkActivityIndicator() {
        self.waitIndicator = SdkActivityIndicator(frame: CGRect(x: 0, y: 0, width: 88, height: 88))
        self.waitIndicator.indicatorColor = UIColor.sdkDefaultGreenColor
        self.view.addSubview(self.waitIndicator)
        self.waitIndicator.center = self.view.center
        self.waitIndicator.hideIndicatorWhenStopped = true
    }
    
    func fontInterPreload() {
        didLabel.font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
        pushTokenLabel .font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
        fcmTokenLabel.font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
        idfaLabel.font = SdkDynamicFont.dynamicFont(textStyle: .headline, weight: .bold)
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
    
    //SDK Advertising identifier support at init user request
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
                            self.idfaLabel.text = idfa.uuidString
                            print("\nSDK: User granted access to 'ios_advertising_id'\nIDFA:", idfa, "\n")
                        case .failure(_):
                            self.idfaLabel.text = "IDFA 0"
                            print("\nSDK: 'ios_advertising_id' Error \nIDFA:", initIdfaResult, "\n")
                            break
                        }
                    })
                case .denied, .restricted:
                    self.idfaLabel.text = "SDK: User denied access to 'ios_advertising_id' IDFA"
                    print("SDK: User denied access to 'ios_advertising_id' IDFA\n")
                case .notDetermined:
                    self.idfaLabel.text = "SDK: User not received an authorization request to 'ios_advertising_id' IDFA"
                    print("SDK: User not received an authorization request to 'ios_advertising_id' IDFA\n")
                @unknown default:
                    self.idfaLabel.text = "SDK: User unknown to 'ios_advertising_id' IDFA"
                    break
                }
            }
        }
    }
    
    func setNavBarAppearance(tintColor: UIColor, barColor: UIColor) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = barColor
        appearance.titleTextAttributes = [.foregroundColor: tintColor]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().tintColor = tintColor
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            if self.revealSideMenuOnTop {
                self.sideMenuTrailingConstraint.constant = self.isExpanded ? 0 : (-self.sideMenuRevealWidth - self.paddingForRotation)
            }
        }
    }

    func animateShadow(targetPosition: CGFloat) {
        UIView.animate(withDuration: 0.5) {
            self.sideMenuShadowView.alpha = (targetPosition == 0) ? 0.6 : 0.0
        }
    }

    func sideMenuState(expanded: Bool) {
        if expanded {
            self.animateSideMenu(targetPosition: self.revealSideMenuOnTop ? 0 : self.sideMenuRevealWidth) { _ in
                self.isExpanded = true
            }
            UIView.animate(withDuration: 0.5) {
                self.sideMenuShadowView.alpha = 0.6
                self.headerSection.alpha = 0.0
            }
        }
        else {
            self.animateSideMenu(targetPosition: self.revealSideMenuOnTop ? (-self.sideMenuRevealWidth - self.paddingForRotation) : 0) { _ in
                self.isExpanded = false
            }
            UIView.animate(withDuration: 0.5) {
                self.sideMenuShadowView.alpha = 0.0
                self.headerSection.alpha = 1.0
            }
        }
    }
    
    func animateSideMenu(targetPosition: CGFloat, completion: @escaping (Bool) -> ()) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
            if self.revealSideMenuOnTop {
                self.sideMenuTrailingConstraint.constant = targetPosition
                //self.parent?.modalPresentationStyle = .fullScreen
                self.view.layoutIfNeeded()
            }
            else {
                self.view.subviews[1].frame.origin.x = targetPosition
            }
        }, completion: completion)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

@available(iOS 14.0, *)
extension MainViewController: UIGestureRecognizerDelegate {
    @objc
    func TapGestureRecognizer(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            if self.isExpanded {
                self.sideMenuState(expanded: false)
            }
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (touch.view?.isDescendant(of: self.sideMenuViewController.view))! {
            return false
        }
        return true
    }
    
    @objc private func handlePanGesture(sender: UIPanGestureRecognizer) {
        
        guard gestureEnabled == true else { return }

        let position: CGFloat = sender.translation(in: self.view).x
        let velocity: CGFloat = sender.velocity(in: self.view).x

        switch sender.state {
        case .began:

            if velocity > 0, self.isExpanded {
                sender.state = .cancelled
            }

            if velocity > 0, !self.isExpanded {
                self.draggingIsEnabled = true
            }
            
            else if velocity < 0, self.isExpanded {
                self.draggingIsEnabled = true
            }

            if self.draggingIsEnabled {
                let velocityThreshold: CGFloat = 550
                if abs(velocity) > velocityThreshold {
                    self.sideMenuState(expanded: self.isExpanded ? false : true)
                    self.draggingIsEnabled = false
                    return
                }

                if self.revealSideMenuOnTop {
                    self.panBaseLocation = 0.0
                    if self.isExpanded {
                        self.panBaseLocation = self.sideMenuRevealWidth
                    }
                }
            }

        case .changed:
            if self.draggingIsEnabled {
                if self.revealSideMenuOnTop {
                    
                    let xLocation: CGFloat = self.panBaseLocation + position
                    let percentage = (xLocation * 150 / self.sideMenuRevealWidth) / self.sideMenuRevealWidth

                    let alpha = percentage >= 0.6 ? 0.6 : percentage
                    self.sideMenuShadowView.alpha = alpha

                    if xLocation <= self.sideMenuRevealWidth {
                        self.sideMenuTrailingConstraint.constant = xLocation - self.sideMenuRevealWidth
                    }
                }
                else {
                    if let recogView = sender.view?.subviews[1] {
                        let percentage = (recogView.frame.origin.x * 150 / self.sideMenuRevealWidth) / self.sideMenuRevealWidth

                        let alpha = percentage >= 0.6 ? 0.6 : percentage
                        self.sideMenuShadowView.alpha = alpha

                        if recogView.frame.origin.x <= self.sideMenuRevealWidth, recogView.frame.origin.x >= 0 {
                            recogView.frame.origin.x = recogView.frame.origin.x + position
                            sender.setTranslation(CGPoint.zero, in: view)
                        }
                    }
                }
            }
        case .ended:
            self.draggingIsEnabled = false
            
            if self.revealSideMenuOnTop {
                let movedMoreThanHalf = self.sideMenuTrailingConstraint.constant > -(self.sideMenuRevealWidth * 1.0)
                self.sideMenuState(expanded: movedMoreThanHalf)
            }
            else {
                if let recogView = sender.view?.subviews[1] {
                    let movedMoreThanHalf = recogView.frame.origin.x > self.sideMenuRevealWidth * 1.0
                    self.sideMenuState(expanded: movedMoreThanHalf)
                }
            }
        default:
            break
        }
    }
}

extension UIViewController {
    @objc @available(iOS 14.0, *)
    func revealViewController() -> MainViewController? {
        var viewController: UIViewController? = self
        
        if viewController != nil && viewController is MainViewController {
            return viewController! as? MainViewController
        }
        while (!(viewController is MainViewController) && viewController?.parent != nil) {
            viewController = viewController?.parent
        }
        if viewController is MainViewController {
            return viewController as? MainViewController
        }
        return nil
    }
}

@available(iOS 14.0, *)
extension MainViewController: ShopSideMenuViewControllerDelegate {
    func selectedCell(_ row: Int) {
//        switch row {
//        case 0:
//            self.showViewController(viewController: UINavigationController.self, storyboardId: "HomeNavID")
//        case 1:
//            self.showViewController(viewController: UINavigationController.self, storyboardId: "MusicNavID")
//        case 2:
//            self.showViewController(viewController: UINavigationController.self, storyboardId: "MoviesNavID")
//        case 3:
//            self.showViewController(viewController: UINavigationController.self, storyboardId: "BooksVCID")
//        case 4:
//            let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
//            let profileModalVC = storyboard.instantiateViewController(withIdentifier: "ProfileModalID") as? UISearchContainerViewController
//            present(profileModalVC!, animated: true, completion: nil)
//        case 5:
//            self.showViewController(viewController: UINavigationController.self, storyboardId: "SettingsNavID")
//        case 6:
//            let safariVC = SFSafariViewController(url: URL(string: "https://")!)
//            present(safariVC, animated: true)
//        default:
//            break
//        }

        DispatchQueue.main.async { self.sideMenuState(expanded: false) }
    }

    func showViewController<T: UIViewController>(viewController: T.Type, storyboardId: String) -> () {
        for subview in view.subviews {
            if subview.tag == 99 {
                subview.removeFromSuperview()
            }
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: storyboardId) as! T
        vc.modalPresentationStyle = .fullScreen
        vc.view.tag = 99
        view.insertSubview(vc.view, at: self.revealSideMenuOnTop ? 0 : 1)
        addChild(vc)
        
        DispatchQueue.main.async {
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                vc.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                vc.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                vc.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                vc.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
            ])
        }
        if !self.revealSideMenuOnTop {
            if isExpanded {
                vc.view.frame.origin.x = self.sideMenuRevealWidth
            }
            if self.sideMenuShadowView != nil {
                vc.view.addSubview(self.sideMenuShadowView)
            }
        }
        vc.didMove(toParent: self)
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
        layer.cornerRadius = 11
        //layer.cornerRadius = frame.size.height / 2
    }
}
