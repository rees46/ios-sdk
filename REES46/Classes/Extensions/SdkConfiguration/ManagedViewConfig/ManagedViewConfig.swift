import Foundation

public class ManagedViewConfig {
    public static let configurationKey = "com.sdk.configuration.managed"
    public static let feedbackKey = "com.sdk.feedback.managed"

    public static let shared = ManagedViewConfig()

    public typealias GrabStateFunction = ([String: Any?]) -> Void

    private var configGrabStates = [GrabStateFunction]()
    private var feedbackGrabStates = [GrabStateFunction]()

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(ManagedViewConfig.didChange), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    public func addViewAppConfigChangedGrabState(_ appConfigChangedGrabState: @escaping GrabStateFunction) {
        configGrabStates.append(appConfigChangedGrabState)
    }
    
    public func addAppFeedbackChangedGrabState(_ appFeedbackChangedGrabState: @escaping GrabStateFunction) {
        feedbackGrabStates.append(appFeedbackChangedGrabState)
    }
    
    @objc func didChange() {
        if let configDict = UserDefaults.standard.dictionary(forKey: Self.configurationKey) {
            for hook in configGrabStates {
                hook(configDict)
            }
        }
        
        if let feedbackDict = UserDefaults.standard.dictionary(forKey: Self.feedbackKey) {
            for hook in feedbackGrabStates {
                hook(feedbackDict)
            }
        }
    }
    
    public func getConfigValue(forKey: String) -> Any? {
        if let sdkConfig = UserDefaults.standard.dictionary(forKey: Self.configurationKey) {
            return sdkConfig[forKey]
        }
        return nil
    }

    public func getFeedbackValue(forKey: String) -> Any? {
        if let sdkConfigFeedback = UserDefaults.standard.dictionary(forKey: Self.feedbackKey) {
            return sdkConfigFeedback[forKey]
        }
        return nil
    }

    public func updateStoredValue(_ value: Any, forKey: String) {
        if var sdkConfigFeedback = UserDefaults.standard.dictionary(forKey: Self.feedbackKey) {
            sdkConfigFeedback[forKey] = value
            UserDefaults.standard.set(sdkConfigFeedback, forKey: Self.feedbackKey)
        } else {
            let feedbackDict = [forKey: value]
            UserDefaults.standard.set(feedbackDict, forKey: Self.feedbackKey)
        }
    }
}
