import Foundation

struct User:Codable {
    let slideId:String
    let slideUrl:String
}

@propertyWrapper

    struct UserDefault<T: Codable> {
        let key: String
        let defaultValue: T

        init(_ key: String, defaultValue: T) {
            self.key = key
            self.defaultValue = defaultValue
        }

        var wrappedValue: T {
            get {

                if let data = UserDefaults.standard.object(forKey: key) as? Data,
                    let user = try? JSONDecoder().decode(T.self, from: data) {
                    return user

                }

                return  defaultValue
            }
            set {
                if let encoded = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(encoded, forKey: key)
                }
            }
        }
    }

enum GlobalSettings {
    @UserDefault("user", defaultValue: User(slideId:"", slideUrl:"")) static var user: User
}


extension UserDefaults {
    
    public struct Key {
        fileprivate let name: String
        public init(_ name: String) {
            self.name = name
        }
    }
    
    public func getValue(for key: Key) -> Any? {
        return object(forKey: key.name)
    }
    
    public func setValue(_ value: Any?, for key: Key) {
        set(value, forKey: key.name)
    }
    
    public func removeValue(for key: Key) {
        removeObject(forKey: key.name)
    }
}
