import Foundation
import SwiftUI

@available(iOS 14.0, *)
@propertyWrapper public struct ViewConfig<InternalValue>: DynamicProperty {
    
    private final class Listener<Value>: ObservableObject {
        var subscriber: NSObjectProtocol?
        var value: Value? {
            willSet {
                self.objectWillChange.send()
            }
        }

        func listenTo(store: UserDefaults, key: String, defaultValue: Value) {
            if subscriber == nil {
                ViewConfigService.shared.use(userDefaults: store)
                value = ViewConfigService.shared.value(for: key, store) ?? defaultValue
                subscriber = NotificationCenter.default.addObserver(forName: .sdkConfigChanged,
                                                    object: store, queue: nil) { [weak self] _ in
                    guard let self = self else { return }
                    self.value = ViewConfigService.shared.value(for: key, store) ?? defaultValue
                }
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self, name: .sdkConfigChanged, object: nil)
        }
    }

    @StateObject private var core = Listener<InternalValue>()
    private let key: String
    private let defaults: UserDefaults
    private let defaultValue: InternalValue

    public var wrappedValue: InternalValue {
        core.value ?? defaultValue
    }

    public func update() {
        core.listenTo(store: self.defaults, key: key, defaultValue: defaultValue)
    }

    public init(wrappedValue defaultValue: InternalValue, _ key: String, store: UserDefaults = UserDefaults.standard) {
        self.key = key
        self.defaults = store
        self.defaultValue = defaultValue
    }

    public init(_ key: String, store: UserDefaults = UserDefaults.standard) where InternalValue: ExpressibleByNilLiteral {
        self.key = key
        self.defaultValue = nil
        self.defaults = store
    }
}
