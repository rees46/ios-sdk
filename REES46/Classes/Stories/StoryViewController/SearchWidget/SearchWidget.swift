import UIKit

open class SearchWidget: NSObject {
    var pref: UserDefaults!
    
    public static let shared: SearchWidget = SearchWidget()

    public override init() {
        pref = UserDefaults.standard
    }
    
    open func setCategories(value: [String]) {
        pref.set(value, forKey: "categoriesSearch")
    }
    
    open func getCategories() -> [String]? {
        guard let categories = pref.object(forKey: "categoriesSearch") as? [String] else {
            return nil
        }
        return categories
    }

    open func setSearchHistories(value: [String]) {
        pref.set(value, forKey: "historiesSearch")
    }
    
    open func deleteSearchHistories(index: Int) {
        guard var histories = pref.object(forKey: "historiesSearch") as? [String] else {
            return
        }
        histories.remove(at: index)
        
        pref.set(histories, forKey: "historiesSearch")
    }
    
    open func appendSearchHistories(value: String) {
        var histories = [String]()
        if let _histories = pref.object(forKey: "historiesSearch") as? [String] {
            histories = _histories
        }
        histories.append(value)

        pref.set(histories, forKey: "historiesSearch")
    }
    
    open func getSearchHistories() -> [String]? {
        guard let histories = pref.object(forKey: "historiesSearch") as? [String] else {
            return nil
        }
        
        return histories
    }
}
