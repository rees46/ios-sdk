import Foundation

@propertyWrapper public struct ViewConfigPlain<Value> {
    
    private final class Listener<ListenerValue> {
        
        var subscriber: NSObjectProtocol?
        var value: Value?

        func listenTo(store: UserDefaults, key: String, defaultValue: Value) {
            if subscriber == nil {
                ViewConfigService.configShared.use(userDefaults: store)
                value = ViewConfigService.configShared.value(for: key, store) ?? defaultValue
                
                subscriber = NotificationCenter.default.addObserver(forName: .sdkConfigChanged, object: store, queue: nil) { [weak self] _ in
                    guard let self = self else {
                        return
                    }
                    self.value = ViewConfigService.configShared.value(for: key, store) ?? defaultValue
                }
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self, name: .sdkConfigChanged, object: nil)
        }
    }

    private var listener = Listener<Value>()
    
    private let defaultValue: Value

    public var wrappedValue: Value {
        listener.value ?? defaultValue
    }

    public init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults = UserDefaults.standard) {
        self.defaultValue = defaultValue
        listener.listenTo(store: store, key: key, defaultValue: defaultValue)
    }

    public init(_ key: String, store: UserDefaults = UserDefaults.standard) where Value: ExpressibleByNilLiteral {
        self.defaultValue = nil
        listener.listenTo(store: store, key: key, defaultValue: nil)
    }
}
