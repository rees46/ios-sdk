//
//  UserDefaultsExtension.swift
//  R
//
//  Created by pp on 2023/04/19.
//  Copyright © 2023. All rights reserved.
//

import Foundation

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

extension UserDefaults.Key {
    static let currentStory = UserDefaults.Key("currentStory")
}
