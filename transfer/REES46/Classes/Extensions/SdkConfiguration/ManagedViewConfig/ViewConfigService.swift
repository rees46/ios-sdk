import Foundation

extension Notification.Name {
    public static let sdkConfigChanged = Self("sdkConfigChanged")
}

class ViewConfigService {
    static let configShared = ViewConfigService()

    private var dictionaries: [UserDefaults: [String: Any]] = [:]
    private var observers: [UserDefaults: any NSObjectProtocol] = [:]

    func use(userDefaults: UserDefaults) {
        
        if dictionaries[userDefaults] == nil {
            
            dictionaries[userDefaults] = userDefaults.dictionary(forKey: ManagedViewConfig.configurationKey) ?? [:]
            let center = NotificationCenter.default
            observers[userDefaults] = center.addObserver(forName: UserDefaults.didChangeNotification,
                                                         object: userDefaults,
                                                         queue: .main) { [weak self] (note: Notification) in
                guard let self = self else {
                    return
                }
                
                if let defaults = note.object as? UserDefaults {
                    let newValues = defaults.dictionary(forKey: ManagedViewConfig.configurationKey) ?? [:]
                    let mustNotify = !newValues.isEmpty || !(self.dictionaries[defaults]?.isEmpty ?? true)
                    self.dictionaries[defaults] = newValues
                    
                    if mustNotify {
                        NotificationCenter.default.post(name: .sdkConfigChanged, object: defaults)
                    }
                }
            }
        }
    }

    func value<T>(for key: String, _ defaults: UserDefaults) -> T? {
        dictionaries[defaults]?[key] as? T
    }
}
