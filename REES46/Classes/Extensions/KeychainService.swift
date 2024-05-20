import Foundation

enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
}

public let sdkBundleId = Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier ?? "com.bundle.ident.sdk-instanceKeychainService"
public let instanceKeychainService = Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier ?? "com.bundle.ident.sdk-instanceKeychainService"

struct KeychainService {
    static func insertKeychainDidToken(_ token: Data, identifier: String, instanceKeychainService: String = instanceKeychainService) throws {
        let attributes = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: instanceKeychainService,
            kSecAttrAccount: identifier,
            kSecValueData: token
        ] as CFDictionary

        let status = SecItemAdd(attributes, nil)
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func getKeychainDidToken(identifier: String, instanceKeychainService: String = instanceKeychainService) throws -> Data {
        let query = [kSecClass: kSecClassGenericPassword,
               kSecAttrService: instanceKeychainService,
               kSecAttrAccount: identifier,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnData: true
        ] as CFDictionary

        var res: AnyObject?
        let status = SecItemCopyMatching(query, &res)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        return res as! Data
    }
    
    static func updateKeychainDidToken(_ token: Data, identifier: String, instanceKeychainService: String = instanceKeychainService) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: instanceKeychainService,
            kSecAttrAccount: identifier
        ] as CFDictionary

        let attributes = [
            kSecValueData: token
        ] as CFDictionary

        let status = SecItemUpdate(query, attributes)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func upsertKeychainDidToken(_ token: Data, identifier: String, instanceKeychainService: String = instanceKeychainService) throws {
        do {
            _ = try getKeychainDidToken(identifier: identifier, instanceKeychainService: instanceKeychainService)
            try updateKeychainDidToken(token, identifier: identifier, instanceKeychainService: instanceKeychainService)
        } catch KeychainError.itemNotFound {
            try insertKeychainDidToken(token, identifier: identifier, instanceKeychainService: instanceKeychainService)
        }
    }

//    public static func deleteKeychainDidToken(identifier: String, instanceKeychainService: String = instanceKeychainService) throws {
//        let query = [
//            kSecClass: kSecClassGenericPassword,
//            kSecAttrService: instanceKeychainService,
//            kSecAttrAccount: identifier
//        ] as CFDictionary
//
//        let status = SecItemDelete(query)
//        
//        if status == errSecItemNotFound {
//            //debugPrint ("SDK: Keychain errSecItemNotFound")
//        } else if status == errSecNoSuchKeychain {
//            //debugPrint ("SDK: Keychain errSecNoSuchKeychain")
//        }
//        
//        guard status == errSecSuccess || status == errSecItemNotFound else {
//            throw KeychainError.unexpectedStatus(status)
//        }
//    }
}

public struct KeychainResetService {
    public static func deleteKeychainDidToken(identifier: String, instanceKeychainService: String = instanceKeychainService) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: instanceKeychainService,
            kSecAttrAccount: identifier
        ] as CFDictionary

        let status = SecItemDelete(query)
        
        if status == errSecItemNotFound {
            //debugPrint ("SDK: Keychain errSecItemNotFound")
        } else if status == errSecNoSuchKeychain {
            //debugPrint ("SDK: Keychain errSecNoSuchKeychain")
        }
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
