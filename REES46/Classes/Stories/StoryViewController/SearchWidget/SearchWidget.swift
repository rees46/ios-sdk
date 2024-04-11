import UIKit

open class SearchWidget: NSObject {
    var pref: UserDefaults!
    
    public static let shared: SearchWidget = SearchWidget()

    public override init() {
        pref = UserDefaults.standard
    }
    
    open func setCategoriesSuggests(value: [String]) {
        pref.set(value, forKey: "categoriesSearch")
    }
    
    open func getCategories() -> [String]? {
        guard let categories = pref.object(forKey: "categoriesSearch") as? [String] else {
            return nil
        }
        return categories
    }
    
    //
    open func setUserCachedRequests(value: [String]) {
        pref.set(value, forKey: "userCachedRequests")
    }
    
    open func getUserCachedRequests() -> [String]? {
        guard let cReq = pref.object(forKey: "userCachedRequests") as? [String] else {
            return nil
        }
        return cReq
    }

    open func setRequestHistories(value: [String]) {
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
            //return nil
            return ["Shoes", "Dress", "Jacket"]
        }
        
        return histories
    }
    
    open func setSearchSuggest(value: [String]) {
        pref.set(value, forKey: "suggestSearch")
    }
    
    open func deleteSearchSuggest(index: Int) {
        guard var suggests = pref.object(forKey: "suggestSearch") as? [String] else {
            return
        }
        suggests.remove(at: index)
        
        pref.set(suggests, forKey: "suggestSearch")
    }
    
    open func appendSearchSuggest(value: String) {
        var suggests = [String]()
        if let _suggests = pref.object(forKey: "suggestSearch") as? [String] {
            suggests = _suggests
        }
        suggests.append(value)

        pref.set(suggests, forKey: "suggestSearch")
    }
    
    open func getSearchSuggest() -> [String]? {
        guard let suggest = pref.object(forKey: "suggestSearch") as? [String] else {
            return nil
        }
        return suggest
    }
}
