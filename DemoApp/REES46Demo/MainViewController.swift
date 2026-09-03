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

private enum DemoPurchasePredictConstants {
    static let demoEmail = "predict-demo@example.com"
}

private enum DemoPurchaseTrackingConstants {
    static let orderIdMinimal = "ios-demo-order-minimal"
    static let orderIdFull = "ios-demo-order-full"
    static let orderPriceMinimal = 199.0
    static let orderPriceFull = 999.0
    static let itemId = "ios-demo-sku-001"
    static let itemAmount = 1
    static let itemPrice = 99.0
}

private enum DemoTrackEventDemoConstants {
    static let sampleUnixTime = 123_456
    static let successEventName = "custom_event"
    static let category = "demo_category"
    static let label = "demo_label"
    static let sampleValue = 100
    static let safeCustomFieldKey = "demo_custom_key"
    static let safeCustomFieldValue = "ios_demo_app"
    /// Reserved request key; must trigger trackEvent validation error when passed inside customFields.
    static let reservedCollisionKey = "shop_id"
    static let reservedCollisionValue = "collision_demo"
}

private enum DemoTrackingNamespaceConstants {
    static let itemId = "ios-demo-sku-001"
    static let secondItemId = "ios-demo-sku-002"
    static let categoryId = "ios-demo-category"
    static let searchQuery = "demo boots"
    static let quantity = 2
    static let price = 49.9
    static let sourceCode = "ios-demo-block"
}

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
    @IBOutlet private weak var showSnackBarButton: UIButton!
    private var showTestPopupButton: UIButton!
    private var trackEventCustomFieldsSuccessButton: UIButton!
    private var trackEventCustomFieldsCollisionButton: UIButton!
    private var predictDidOnlyButton: UIButton!
    private var predictWithEmailButton: UIButton!
    private var trackPurchaseMinimalButton: UIButton!
    private var trackPurchaseFullButton: UIButton!
    private var getLastOrderProductsButton: UIButton!
    private var getUserOrdersButton: UIButton!
    private var loyaltyJoinButton: UIButton!
    private var loyaltyStatusButton: UIButton!
    private var getProfileButton: UIButton!
    private var getProductCountersButton: UIButton!
    private var getCategoryButton: UIButton!
    private var getCollectionButton: UIButton!
    private var multiInstanceButton: UIButton!
    private var trackingNamespaceButtons: [UIButton] = []

    public var waitIndicator: SdkActivityIndicator!
    
    public var recommendationsCollectionView = RecommendationsWidgetView()
    public var newArrivalsCollectionView = RecommendationsWidgetView()
    private var notificationWidget: NotificationWidget?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSdkObservers()
        setupSdkDemoAppViews()
        setupSdkActivityIndicator()
        loadRecommendationsWidget()
        loadNewArrivalsWidget()
        setupInAppNotifcation()
    }
    
    func setupInAppNotifcation(){
        notificationWidget = NotificationWidget(parentViewController: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        requestTrackingAuthorization()
        super.viewDidAppear(animated)
    }
    
    func addSdkObservers() {
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
                //                self.recommendationsCollectionView.heightAnchor.constraint(equalToConstant: 400).isActive = true //height
                self.recommendationsCollectionView.topAnchor.constraint(equalTo: self.scrollView.topAnchor, constant: 300).isActive = true //top
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
    private func showTestPopup() {
        guard let sdk = globalSDK else {
            return
        }
        
        let componentsDict: [String: Any] = [
            "header": "Test Popup",
            "text": "This is a test popup for iOS SDK"
        ]
        
        let componentsJSON: String
        if let componentsData = try? JSONSerialization.data(withJSONObject: componentsDict),
           let componentsString = String(data: componentsData, encoding: .utf8) {
            componentsJSON = componentsString
        } else {
            componentsJSON = "{}"
        }
        
        let testPopupData: [String: Any] = [
            "id": 999,
            "channels": ["email"],
            "position": "centered",
            "delay": 0,
            "html": """
            <div class="popup-title">Test Popup</div>
            <p class="popup-999__intro">This is a test popup for iOS SDK</p>
            """,
            "components": componentsJSON,
            "web_push_system": false,
            "popup_actions": "{}"
        ]
        
        let testPopup = Popup(json: testPopupData)
        
        sdk.popupPresenter.dismissCurrentPopup()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            sdk.popupPresenter.presentPopup(testPopup)
        }
    }
    
    func setupSdkDemoAppViews() {
        navigationController?.navigationBar.isHidden = true
        scrollView.contentSize = CGSize(width: UIScreen.main.bounds.size.width, height: 2800)
        
        menuButton.addTarget(self, action: #selector(didTapMenu), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(didTapSearch), for: .touchUpInside)
        cartButton.addTarget(self, action: #selector(didTapCart), for: .touchUpInside)
        updateDidButton.addTarget(self, action: #selector(didTapUpdate), for: .touchUpInside)
        resetDidButton.addTarget(self, action: #selector(didTapReset), for: .touchUpInside)
        
        setupTestPopupButton()
        setupTrackEventDemoButtons()
        setupPurchasePredictDemoButtons()
        setupTrackPurchaseDemoButtons()
        setupGetLastOrderProductsButton()
        setupGetUserOrdersButton()
        setupLoyaltyJoinButton()
        setupLoyaltyStatusButton()
        setupGetProfileButton()
        setupGetProductCountersButton()
        setupGetCategoryButton()
        setupGetCollectionButton()
        setupMultiInstanceButton()
        setupTrackingNamespaceButtons()

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
            
            // R2: the did lives in the shop's partition, not `.standard` — read it from the instance.
            let deviceId = globalSDK?.getDeviceId() ?? "No did token"
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
    
    func setupTestPopupButton() {
        showTestPopupButton = DemoShopButton(type: .system)
        showTestPopupButton.setTitle("Show Test Popup", for: .normal)
        showTestPopupButton.setTitleColor(.white, for: .normal)
        showTestPopupButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(showTestPopupButton)
        
        // Place button next to other test buttons
        NSLayoutConstraint.activate([
            showTestPopupButton.topAnchor.constraint(equalTo: showSnackBarButton.bottomAnchor, constant: 10),
            showTestPopupButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            showTestPopupButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            showTestPopupButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor)
        ])
        
        showTestPopupButton.addTarget(self, action: #selector(showTestPopup), for: .touchUpInside)
    }
    
    func setupTrackEventDemoButtons() {
        trackEventCustomFieldsSuccessButton = DemoShopButton(type: .system)
        trackEventCustomFieldsSuccessButton.setTitle("Track event (custom fields)", for: .normal)
        trackEventCustomFieldsSuccessButton.setTitleColor(.white, for: .normal)
        trackEventCustomFieldsSuccessButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(trackEventCustomFieldsSuccessButton)
        
        trackEventCustomFieldsCollisionButton = DemoShopButton(type: .system)
        trackEventCustomFieldsCollisionButton.setTitle("Track event (reserved key collision)", for: .normal)
        trackEventCustomFieldsCollisionButton.setTitleColor(.white, for: .normal)
        trackEventCustomFieldsCollisionButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(trackEventCustomFieldsCollisionButton)
        
        NSLayoutConstraint.activate([
            trackEventCustomFieldsSuccessButton.topAnchor.constraint(equalTo: showTestPopupButton.bottomAnchor, constant: 10),
            trackEventCustomFieldsSuccessButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            trackEventCustomFieldsSuccessButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            trackEventCustomFieldsSuccessButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
            
            trackEventCustomFieldsCollisionButton.topAnchor.constraint(equalTo: trackEventCustomFieldsSuccessButton.bottomAnchor, constant: 10),
            trackEventCustomFieldsCollisionButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            trackEventCustomFieldsCollisionButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            trackEventCustomFieldsCollisionButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor)
        ])
        
        trackEventCustomFieldsSuccessButton.addTarget(self, action: #selector(didTapTrackEventCustomFieldsSuccess), for: .touchUpInside)
        trackEventCustomFieldsCollisionButton.addTarget(self, action: #selector(didTapTrackEventCustomFieldsCollision), for: .touchUpInside)
    }

    func setupPurchasePredictDemoButtons() {
        predictDidOnlyButton = DemoShopButton(type: .system)
        predictDidOnlyButton.setTitle("Predict purchase (did only)", for: .normal)
        predictDidOnlyButton.setTitleColor(.white, for: .normal)
        predictDidOnlyButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(predictDidOnlyButton)

        predictWithEmailButton = DemoShopButton(type: .system)
        predictWithEmailButton.setTitle("Predict purchase (did + email)", for: .normal)
        predictWithEmailButton.setTitleColor(.white, for: .normal)
        predictWithEmailButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(predictWithEmailButton)

        NSLayoutConstraint.activate([
            predictDidOnlyButton.topAnchor.constraint(equalTo: trackEventCustomFieldsCollisionButton.bottomAnchor, constant: 24),
            predictDidOnlyButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            predictDidOnlyButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            predictDidOnlyButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),

            predictWithEmailButton.topAnchor.constraint(equalTo: predictDidOnlyButton.bottomAnchor, constant: 10),
            predictWithEmailButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            predictWithEmailButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            predictWithEmailButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor)
        ])

        predictDidOnlyButton.addTarget(self, action: #selector(didTapPredictDidOnly), for: .touchUpInside)
        predictWithEmailButton.addTarget(self, action: #selector(didTapPredictWithEmail), for: .touchUpInside)
    }

    @objc
    private func didTapPredictDidOnly() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        sdk.getProbabilityToPurchase(params: PurchasePredictParams()) { result in
            switch result {
            case .success(let response):
                let message = String(format: "probability=%.4f\nclient_id=%@", response.probability, response.clientId)
                self.presentTrackEventDemoAlert(title: "Predict", message: message)
            case .failure(let error):
                self.presentTrackEventDemoAlert(title: "Predict failed", message: Self.sdkErrorDescription(error))
            }
        }
    }

    @objc
    private func didTapPredictWithEmail() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        let params = PurchasePredictParams(email: DemoPurchasePredictConstants.demoEmail)
        sdk.getProbabilityToPurchase(params: params) { result in
            switch result {
            case .success(let response):
                let message = String(format: "probability=%.4f\nclient_id=%@", response.probability, response.clientId)
                self.presentTrackEventDemoAlert(title: "Predict", message: message)
            case .failure(let error):
                self.presentTrackEventDemoAlert(title: "Predict failed", message: Self.sdkErrorDescription(error))
            }
        }
    }

    func setupTrackPurchaseDemoButtons() {
        trackPurchaseMinimalButton = DemoShopButton(type: .system)
        trackPurchaseMinimalButton.setTitle("Track purchase (minimal)", for: .normal)
        trackPurchaseMinimalButton.setTitleColor(.white, for: .normal)
        trackPurchaseMinimalButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(trackPurchaseMinimalButton)

        trackPurchaseFullButton = DemoShopButton(type: .system)
        trackPurchaseFullButton.setTitle("Track purchase (full)", for: .normal)
        trackPurchaseFullButton.setTitleColor(.white, for: .normal)
        trackPurchaseFullButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(trackPurchaseFullButton)

        NSLayoutConstraint.activate([
            // Place after the predict buttons (which are placed after the trackEvent buttons).
            trackPurchaseMinimalButton.topAnchor.constraint(equalTo: predictWithEmailButton.bottomAnchor, constant: 24),
            trackPurchaseMinimalButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            trackPurchaseMinimalButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            trackPurchaseMinimalButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),

            trackPurchaseFullButton.topAnchor.constraint(equalTo: trackPurchaseMinimalButton.bottomAnchor, constant: 10),
            trackPurchaseFullButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            trackPurchaseFullButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            trackPurchaseFullButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        trackPurchaseMinimalButton.addTarget(self, action: #selector(didTapTrackPurchaseMinimal), for: .touchUpInside)
        trackPurchaseFullButton.addTarget(self, action: #selector(didTapTrackPurchaseFull), for: .touchUpInside)
    }

    func setupGetLastOrderProductsButton() {
        getLastOrderProductsButton = DemoShopButton(type: .system)
        getLastOrderProductsButton.setTitle("Get last order products", for: .normal)
        getLastOrderProductsButton.setTitleColor(.white, for: .normal)
        getLastOrderProductsButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(getLastOrderProductsButton)

        NSLayoutConstraint.activate([
            getLastOrderProductsButton.topAnchor.constraint(equalTo: trackPurchaseFullButton.bottomAnchor, constant: 24),
            getLastOrderProductsButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            getLastOrderProductsButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            getLastOrderProductsButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        getLastOrderProductsButton.addTarget(self, action: #selector(didTapGetLastOrderProducts), for: .touchUpInside)
    }

    func setupGetUserOrdersButton() {
        getUserOrdersButton = DemoShopButton(type: .system)
        getUserOrdersButton.setTitle("Get user orders", for: .normal)
        getUserOrdersButton.setTitleColor(.white, for: .normal)
        getUserOrdersButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(getUserOrdersButton)

        NSLayoutConstraint.activate([
            getUserOrdersButton.topAnchor.constraint(equalTo: getLastOrderProductsButton.bottomAnchor, constant: 10),
            getUserOrdersButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            getUserOrdersButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            getUserOrdersButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        getUserOrdersButton.addTarget(self, action: #selector(didTapGetUserOrders), for: .touchUpInside)
    }

    @objc
    private func didTapGetUserOrders() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        // Placeholder secret for demo only — orders/by_user requires a real server-side shop_secret.
        sdk.getUserOrders(shopSecret: "demo-shop-secret") { result in
            switch result {
            case .success(let orders):
                self.presentTrackEventDemoAlert(
                    title: "User orders",
                    message: "Received \(orders.count) order(s)."
                )
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "getUserOrders failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }

    @objc
    private func didTapGetLastOrderProducts() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        sdk.getLastOrderProducts { result in
            switch result {
            case .success(let response):
                self.presentTrackEventDemoAlert(
                    title: "Last order products",
                    message: "Received \(response.products.count) product(s)."
                )
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "getLastOrderProducts failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }

    func setupLoyaltyJoinButton() {
        loyaltyJoinButton = DemoShopButton(type: .system)
        loyaltyJoinButton.setTitle("Loyalty: join", for: .normal)
        loyaltyJoinButton.setTitleColor(.white, for: .normal)
        loyaltyJoinButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(loyaltyJoinButton)

        NSLayoutConstraint.activate([
            loyaltyJoinButton.topAnchor.constraint(equalTo: getUserOrdersButton.bottomAnchor, constant: 24),
            loyaltyJoinButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            loyaltyJoinButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            loyaltyJoinButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        loyaltyJoinButton.addTarget(self, action: #selector(didTapLoyaltyJoin), for: .touchUpInside)
    }

    func setupLoyaltyStatusButton() {
        loyaltyStatusButton = DemoShopButton(type: .system)
        loyaltyStatusButton.setTitle("Loyalty: status", for: .normal)
        loyaltyStatusButton.setTitleColor(.white, for: .normal)
        loyaltyStatusButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(loyaltyStatusButton)

        NSLayoutConstraint.activate([
            loyaltyStatusButton.topAnchor.constraint(equalTo: loyaltyJoinButton.bottomAnchor, constant: 10),
            loyaltyStatusButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            loyaltyStatusButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            loyaltyStatusButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        loyaltyStatusButton.addTarget(self, action: #selector(didTapLoyaltyStatus), for: .touchUpInside)
    }

    @objc
    private func didTapLoyaltyJoin() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        sdk.joinLoyalty(
            phone: "79991234567",
            email: "demo@rees46.ru",
            firstName: "Demo",
            lastName: "User"
        ) { result in
            switch result {
            case .success(let response):
                self.presentTrackEventDemoAlert(
                    title: "Loyalty join",
                    message: "status: \(response.status ?? "—")"
                )
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "joinLoyalty failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }

    @objc
    private func didTapLoyaltyStatus() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        sdk.getLoyaltyStatus(identifier: "79991234567") { result in
            switch result {
            case .success(let response):
                self.presentTrackEventDemoAlert(
                    title: "Loyalty status",
                    message: "status: \(response.status ?? "—"), member: \(response.member.map(String.init) ?? "—"), level: \(response.level?.name ?? "—")"
                )
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "getLoyaltyStatus failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }

    func setupGetProfileButton() {
        getProfileButton = DemoShopButton(type: .system)
        getProfileButton.setTitle("Profile: get", for: .normal)
        getProfileButton.setTitleColor(.white, for: .normal)
        getProfileButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(getProfileButton)

        NSLayoutConstraint.activate([
            getProfileButton.topAnchor.constraint(equalTo: loyaltyStatusButton.bottomAnchor, constant: 24),
            getProfileButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            getProfileButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            getProfileButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        getProfileButton.addTarget(self, action: #selector(didTapGetProfile), for: .touchUpInside)
    }

    func setupGetProductCountersButton() {
        getProductCountersButton = DemoShopButton(type: .system)
        getProductCountersButton.setTitle("Products: counters", for: .normal)
        getProductCountersButton.setTitleColor(.white, for: .normal)
        getProductCountersButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(getProductCountersButton)

        NSLayoutConstraint.activate([
            getProductCountersButton.topAnchor.constraint(equalTo: getProfileButton.bottomAnchor, constant: 10),
            getProductCountersButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            getProductCountersButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            getProductCountersButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        getProductCountersButton.addTarget(self, action: #selector(didTapGetProductCounters), for: .touchUpInside)
    }

    func setupGetCategoryButton() {
        getCategoryButton = DemoShopButton(type: .system)
        getCategoryButton.setTitle("Category: list", for: .normal)
        getCategoryButton.setTitleColor(.white, for: .normal)
        getCategoryButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(getCategoryButton)

        NSLayoutConstraint.activate([
            getCategoryButton.topAnchor.constraint(equalTo: getProductCountersButton.bottomAnchor, constant: 10),
            getCategoryButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            getCategoryButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            getCategoryButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        getCategoryButton.addTarget(self, action: #selector(didTapGetCategory), for: .touchUpInside)
    }

    @objc
    private func didTapGetProfile() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        sdk.getProfile { result in
            switch result {
            case .success(let response):
                self.presentTrackEventDemoAlert(
                    title: "Profile",
                    message: "id: \(response.id ?? "—"), hasEmail: \(response.hasEmail.map(String.init) ?? "—"), gender: \(response.gender ?? "—")"
                )
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "getProfile failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }

    @objc
    private func didTapGetProductCounters() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        sdk.getProductCounters(item: "300275") { result in
            switch result {
            case .success(let response):
                self.presentTrackEventDemoAlert(
                    title: "Product counters",
                    message: "now.view: \(response.now?.view ?? 0), price_drop: \(response.triggers?.priceDrop ?? 0)"
                )
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "getProductCounters failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }

    @objc
    private func didTapGetCategory() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        sdk.getCategory(category: "smartfony-i-gadzhety", limit: 5) { result in
            switch result {
            case .success(let response):
                self.presentTrackEventDemoAlert(
                    title: "Category",
                    message: "total: \(response.productsTotal), products: \(response.products.count)"
                )
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "getCategory failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }

    func setupGetCollectionButton() {
        getCollectionButton = DemoShopButton(type: .system)
        getCollectionButton.setTitle("Collection: get", for: .normal)
        getCollectionButton.setTitleColor(.white, for: .normal)
        getCollectionButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(getCollectionButton)

        NSLayoutConstraint.activate([
            getCollectionButton.topAnchor.constraint(equalTo: getCategoryButton.bottomAnchor, constant: 10),
            getCollectionButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            getCollectionButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            getCollectionButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        getCollectionButton.addTarget(self, action: #selector(didTapGetCollection), for: .touchUpInside)
    }

    func setupMultiInstanceButton() {
        multiInstanceButton = DemoShopButton(type: .system)
        multiInstanceButton.setTitle("Multi-instance demo", for: .normal)
        multiInstanceButton.setTitleColor(.white, for: .normal)
        multiInstanceButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(multiInstanceButton)

        NSLayoutConstraint.activate([
            multiInstanceButton.topAnchor.constraint(equalTo: getCollectionButton.bottomAnchor, constant: 10),
            multiInstanceButton.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
            multiInstanceButton.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
            multiInstanceButton.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
        ])

        multiInstanceButton.addTarget(self, action: #selector(didTapMultiInstance), for: .touchUpInside)
    }

    @objc private func didTapMultiInstance() {
        let nav = UINavigationController(rootViewController: MultiInstanceViewController())
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - Tracking namespace (sdk.tracking.*)

    /// One button per standard event, all of them going through the `tracking` namespace.
    /// The identifiers are what `TrackingNamespaceUITests` taps.
    func setupTrackingNamespaceButtons() {
        let actions: [(title: String, identifier: String, selector: Selector)] = [
            ("Tracking: product view", "tracking_product_view", #selector(didTapTrackingProductView)),
            ("Tracking: category view", "tracking_category_view", #selector(didTapTrackingCategoryView)),
            ("Tracking: search", "tracking_search", #selector(didTapTrackingSearch)),
            ("Tracking: add to cart", "tracking_add_to_cart", #selector(didTapTrackingAddToCart)),
            ("Tracking: sync cart", "tracking_sync_cart", #selector(didTapTrackingSyncCart)),
            ("Tracking: remove from cart", "tracking_remove_from_cart", #selector(didTapTrackingRemoveFromCart)),
            ("Tracking: add to favorites", "tracking_add_to_favorites", #selector(didTapTrackingAddToFavorites)),
            ("Tracking: sync favorites", "tracking_sync_favorites", #selector(didTapTrackingSyncFavorites)),
            ("Tracking: remove from favorites", "tracking_remove_from_favorites", #selector(didTapTrackingRemoveFromFavorites)),
            ("Tracking: set source", "tracking_set_source", #selector(didTapTrackingSetSource)),
        ]

        var previous: UIView = multiInstanceButton
        for action in actions {
            let button = DemoShopButton(type: .system)
            button.setTitle(action.title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.accessibilityIdentifier = action.identifier
            button.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(button)

            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: 10),
                button.leadingAnchor.constraint(equalTo: showSnackBarButton.leadingAnchor),
                button.widthAnchor.constraint(equalTo: showSnackBarButton.widthAnchor),
                button.heightAnchor.constraint(equalTo: showSnackBarButton.heightAnchor),
            ])

            button.addTarget(self, action: action.selector, for: .touchUpInside)
            trackingNamespaceButtons.append(button)
            previous = button
        }
    }

    /// Runs one namespace call and reports the outcome in an alert titled `<method> OK` or
    /// `<method> failed` — the UI test asserts on exactly those titles.
    private func runTrackingDemo(
        _ method: String,
        _ call: (TrackingAPI, @escaping (Result<Void, SdkError>) -> Void) -> Void
    ) {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        call(sdk.tracking) { result in
            switch result {
            case .success:
                self.presentTrackEventDemoAlert(
                    title: "\(method) OK",
                    message: "Sent through sdk.tracking.\(method)."
                )
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "\(method) failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }

    @objc
    private func didTapTrackingProductView() {
        runTrackingDemo("productView") { tracking, done in
            tracking.productView(
                itemId: DemoTrackingNamespaceConstants.itemId,
                source: TrackingSource(type: .dynamic, code: DemoTrackingNamespaceConstants.sourceCode),
                completion: done
            )
        }
    }

    @objc
    private func didTapTrackingCategoryView() {
        runTrackingDemo("categoryView") { tracking, done in
            tracking.categoryView(categoryId: DemoTrackingNamespaceConstants.categoryId, completion: done)
        }
    }

    @objc
    private func didTapTrackingSearch() {
        runTrackingDemo("search") { tracking, done in
            tracking.search(
                query: DemoTrackingNamespaceConstants.searchQuery,
                results: [DemoTrackingNamespaceConstants.itemId, DemoTrackingNamespaceConstants.secondItemId],
                completion: done
            )
        }
    }

    @objc
    private func didTapTrackingAddToCart() {
        runTrackingDemo("addToCart") { tracking, done in
            tracking.addToCart(
                item: TrackingItem(
                    id: DemoTrackingNamespaceConstants.itemId,
                    quantity: DemoTrackingNamespaceConstants.quantity,
                    price: DemoTrackingNamespaceConstants.price
                ),
                completion: done
            )
        }
    }

    @objc
    private func didTapTrackingSyncCart() {
        runTrackingDemo("syncCart") { tracking, done in
            tracking.syncCart(
                items: [
                    TrackingItem(
                        id: DemoTrackingNamespaceConstants.itemId,
                        quantity: DemoTrackingNamespaceConstants.quantity,
                        price: DemoTrackingNamespaceConstants.price
                    ),
                    TrackingItem(id: DemoTrackingNamespaceConstants.secondItemId),
                ],
                completion: done
            )
        }
    }

    @objc
    private func didTapTrackingRemoveFromCart() {
        runTrackingDemo("removeFromCart") { tracking, done in
            tracking.removeFromCart(itemId: DemoTrackingNamespaceConstants.itemId, completion: done)
        }
    }

    @objc
    private func didTapTrackingAddToFavorites() {
        runTrackingDemo("addToFavorites") { tracking, done in
            tracking.addToFavorites(itemId: DemoTrackingNamespaceConstants.itemId, completion: done)
        }
    }

    @objc
    private func didTapTrackingSyncFavorites() {
        runTrackingDemo("syncFavorites") { tracking, done in
            tracking.syncFavorites(
                itemIds: [
                    DemoTrackingNamespaceConstants.itemId,
                    DemoTrackingNamespaceConstants.secondItemId,
                ],
                completion: done
            )
        }
    }

    @objc
    private func didTapTrackingRemoveFromFavorites() {
        runTrackingDemo("removeFromFavorites") { tracking, done in
            tracking.removeFromFavorites(itemId: DemoTrackingNamespaceConstants.itemId, completion: done)
        }
    }

    /// `setSource` stores the attribution locally and has no completion — report it as sent.
    @objc
    private func didTapTrackingSetSource() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        sdk.tracking.setSource(
            TrackingSource(type: .dynamic, code: DemoTrackingNamespaceConstants.sourceCode)
        )
        presentTrackEventDemoAlert(
            title: "setSource OK",
            message: "Stored source for the next events."
        )
    }

    @objc
    private func didTapGetCollection() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        sdk.getCollection(collectionId: "1") { result in
            switch result {
            case .success(let response):
                self.presentTrackEventDemoAlert(
                    title: "Collection",
                    message: "products: \(response.products.count)"
                )
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "getCollection failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }

    private func presentTrackEventDemoAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    private static func sdkErrorDescription(_ error: SdkError) -> String {
        switch error {
        case .custom(let message):
            return message
        default:
            return String(describing: error)
        }
    }
    
    @objc
    private func didTapTrackEventCustomFieldsSuccess() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        
        let customFields: [String: Any] = [
            DemoTrackEventDemoConstants.safeCustomFieldKey: DemoTrackEventDemoConstants.safeCustomFieldValue
        ]
        
        sdk.tracking.custom(
            event: DemoTrackEventDemoConstants.successEventName,
            time: DemoTrackEventDemoConstants.sampleUnixTime,
            category: DemoTrackEventDemoConstants.category,
            label: DemoTrackEventDemoConstants.label,
            value: DemoTrackEventDemoConstants.sampleValue,
            customFields: customFields
        ) { result in
            switch result {
            case .success:
                self.presentTrackEventDemoAlert(title: "trackEvent", message: "Request sent (custom fields OK).")
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "trackEvent failed",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
    }
    
    @objc
    private func didTapTrackPurchaseMinimal() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        let request = PurchaseTrackingRequest(
            orderId: DemoPurchaseTrackingConstants.orderIdMinimal,
            orderPrice: DemoPurchaseTrackingConstants.orderPriceMinimal,
            items: [
                PurchaseItemRequest(
                    id: DemoPurchaseTrackingConstants.itemId,
                    amount: DemoPurchaseTrackingConstants.itemAmount,
                    price: DemoPurchaseTrackingConstants.itemPrice
                ),
            ]
        )
        sdk.tracking.purchase(request) { result in
            switch result {
            case .success:
                self.presentTrackEventDemoAlert(title: "trackPurchase", message: "Request sent (minimal).")
            case .failure(let error):
                self.presentTrackEventDemoAlert(title: "trackPurchase failed", message: Self.sdkErrorDescription(error))
            }
        }
    }

    @objc
    private func didTapTrackPurchaseFull() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        let request = PurchaseTrackingRequest(
            orderId: DemoPurchaseTrackingConstants.orderIdFull,
            orderPrice: DemoPurchaseTrackingConstants.orderPriceFull,
            items: [
                PurchaseItemRequest(
                    id: DemoPurchaseTrackingConstants.itemId,
                    amount: 2,
                    price: 49.99,
                    quantity: 2,
                    lineId: "demo-line-1",
                    fashionSize: "L"
                ),
            ],
            deliveryType: "courier",
            deliveryAddress: "Demo address",
            paymentType: "card",
            isTaxFree: true,
            promocode: "DEMO10",
            orderCash: 100,
            orderBonuses: 10,
            orderDelivery: 5,
            orderDiscount: 15,
            channel: "mobile",
            custom: ["demo_custom": "ios_demo"],
            recommendedSource: ["source_key": "source_value"],
            stream: "demo-stream",
            segment: "A",
            isGiftPackage: true
        )
        sdk.tracking.purchase(request) { result in
            switch result {
            case .success:
                self.presentTrackEventDemoAlert(title: "trackPurchase", message: "Request sent (full).")
            case .failure(let error):
                self.presentTrackEventDemoAlert(title: "trackPurchase failed", message: Self.sdkErrorDescription(error))
            }
        }
    }

    @objc
    private func didTapTrackEventCustomFieldsCollision() {
        guard let sdk = globalSDK else {
            presentTrackEventDemoAlert(title: "SDK", message: "globalSDK is not initialized.")
            return
        }
        
        let customFields: [String: Any] = [
            DemoTrackEventDemoConstants.reservedCollisionKey: DemoTrackEventDemoConstants.reservedCollisionValue
        ]
        
        sdk.tracking.custom(
            event: DemoTrackEventDemoConstants.successEventName,
            time: DemoTrackEventDemoConstants.sampleUnixTime,
            category: DemoTrackEventDemoConstants.category,
            label: DemoTrackEventDemoConstants.label,
            value: DemoTrackEventDemoConstants.sampleValue,
            customFields: customFields
        ) { result in
            switch result {
            case .success:
                self.presentTrackEventDemoAlert(title: "Unexpected", message: "Expected validation failure for reserved customFields keys.")
            case .failure(let error):
                self.presentTrackEventDemoAlert(
                    title: "Reserved keys (expected)",
                    message: Self.sdkErrorDescription(error)
                )
            }
        }
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
