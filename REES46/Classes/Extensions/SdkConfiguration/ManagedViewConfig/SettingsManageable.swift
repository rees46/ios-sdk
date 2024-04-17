import Foundation

protocol SettingsManageable {
    func settingsAddr() -> URL
    func toDictionary() -> [String: Any?]?
    func update() -> Bool
    mutating func preload() -> Bool
    mutating func preloadUsingSettingsFile() -> Bool
    func delete() -> Bool
    mutating func reset() -> Bool
}

extension SettingsManageable where Self: Codable {
    func settingsAddr() -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachesDirectory.appendingPathComponent("\(Self.self).plist")
    }
    
    func toDictionary() -> [String: Any?]? {
        do {
            if FileManager.default.fileExists(atPath: settingsAddr().path) {
                let fileContents = try Data(contentsOf: settingsAddr())
                let dictionary = try PropertyListSerialization.propertyList(from: fileContents, options: .mutableContainersAndLeaves, format: nil) as? [String: Any?]
                return dictionary
            }
        } catch {
            print(error.localizedDescription)
        }
        
        return nil
    }
    
    func update() -> Bool {
        do {
            let encoded = try PropertyListEncoder().encode(self)
            try encoded.write(to: settingsAddr())
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    mutating func preload() -> Bool {
        if FileManager.default.fileExists(atPath: settingsAddr().path) {
            do {
                let fileContents = try Data(contentsOf: settingsAddr())
                self = try PropertyListDecoder().decode(Self.self, from: fileContents)
                return true
            } catch {
                print(error.localizedDescription)
                return false
            }
        } else {
            if update() {
                backupSettingsFile()
                return true
            } else {
                return false
            }
        }
    }
    
    mutating func preloadUsingSettingsFile() -> Bool {
        guard let originalSettingsURL = Bundle.main.url(forResource: "\(Self.self)", withExtension: "plist") else {
            return false
        }
        
        do {
            if !FileManager.default.fileExists(atPath: settingsAddr().path) {
                try FileManager.default.copyItem(at: originalSettingsURL, to: settingsAddr())
            }
            
            let fileContents = try Data(contentsOf: settingsAddr())
            self = try PropertyListDecoder().decode(Self.self, from: fileContents)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    func delete() -> Bool {
        do {
            try FileManager.default.removeItem(at: settingsAddr())
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    private func backupSettingsFile() {
        do {
            try FileManager.default.copyItem(at: settingsAddr(), to: settingsAddr().appendingPathExtension("init"))
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func restoreSettingsFile() -> Bool {
        do {
            try FileManager.default.copyItem(at: settingsAddr().appendingPathExtension("init"), to: settingsAddr())
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    mutating func reset() -> Bool {
        if delete() {
            if !preloadUsingSettingsFile() {
                if restoreSettingsFile() {
                    return preload()
                }
            } else {
                return true
            }
        }
        return false
    }
}
