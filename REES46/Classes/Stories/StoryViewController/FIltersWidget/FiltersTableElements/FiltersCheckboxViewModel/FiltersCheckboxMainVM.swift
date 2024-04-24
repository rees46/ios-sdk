import Foundation
import REES46

enum ItemType {
    case mainfilter
    case nameAndPicture
    case about
    case email
    case attribute
    case rating
    case expand
}

protocol ItemBaseModel {
    var type: ItemType { get }
    var sectionTitle: String { get }
    var rowCount: Int { get }
    var isCollapsible: Bool { get }
    var isCollapsed: Bool { get set }
}

class AppSearchProductMainFilter: ItemBaseModel {
    var rowCount: Int = 5
    
    var type: ItemType = .mainfilter
    var sectionTitle: String = "AppProductMainFilterSection"
    
    var isCollapsible: Bool = false
    var isCollapsed: Bool = false
    
    var filtersItems: [CollpasedMenuPrepare]
    init(filtersValues: [CollpasedMenuPrepare]) {
        self.filtersItems = filtersValues
        self.rowCount = filtersValues.count
    }
}

class FiltersCheckboxMainVM: NSObject {
    func getDataItems(result: @escaping(_ data: [ItemBaseModel]) -> ()) {
        var items = [ItemBaseModel]()
        
        //let filtersItemsItems = AppSearchProductMainFilter(filtersValues: items)
        //items.append(filtersItemsItems)
        
        //let jsonData = dataFromFile("data")
        //let response = try? JSONDecoder().decode(DataResponse.self, from: jsonData!)
//        if let content = response?.data {
//            
//            let filtersItems = content.filters
//            if !filtersItems.isEmpty {
//                let filtersItemsItems = AppSearchProductMainFilter(filtersValues: filtersItems)
//                items.append(filtersItemsItems)
//            }
//            
//            if let name = content.fullName, let pictureUrl = content.about {
//                //let nameAndPicture = ItemNameAndPicture(nameKey: name, integerValue: 0)
//                //items.append(nameAndPicture)
//            }
//            
//            let expand = content.expand
//            if !expand.isEmpty {
//                //let exItems = ItemExpand(expandRating: expand)
//                //items.append(exItems)
//            }
//            
//            if let email = content.email {
//                //let emailItem = ItemEmail(email: email)
//                //items.append(emailItem)
//            }
//            
//            let attributes = content.profileAttributes
//            if !attributes.isEmpty {
//                //let attributesItem = ItemAttribute(attributes: attributes)
//                //items.append(attributesItem)
//            }
//            
//            let rating = content.rating
//            if !rating.isEmpty {
//                //let ratItems = ItemRating(rating: rating)
//              //  items.append(ratItems)
//            }
//            
//            
////            if let about = content.about {
////                let aboutItem = ItemAbout(about: about)
////                items.append(aboutItem)
////            }
////            let expand = content.expand
////            if !expand.isEmpty {
////                let exItems = ItemExpand(expandRating: expand)
////                items.append(exItems)
////            }
//        }
            
        result(items)
    }
}
//
//class ItemNameAndPicture: ItemBaseModel {
//    var rowCount: Int = 0 //1
//    
//    var type: ItemType = .nameAndPicture
//    var sectionTitle: String = "Size"
//    
//    var isCollapsible: Bool = false
//    var isCollapsed = false
//    
//    var nameKey: String
//    var integerValue: Int
//    init(nameKey: String, integerValue: Int) {
//        self.nameKey = nameKey
//        self.integerValue = integerValue
//    }
//}
//
//class ItemAbout: ItemBaseModel {
//    var rowCount: Int = 7 //1
//    
//    var type: ItemType = .about
//    var sectionTitle: String = ""
//    
//    var isCollapsible: Bool = false
//    var isCollapsed: Bool = false
//    var about: String
//    
//    init(about: String) {
//        self.about = about
//    }
//}
//
//class ItemEmail: ItemBaseModel {
//    var rowCount: Int = 0
//    
//    var type: ItemType  = .email
//    var sectionTitle: String = "Type"
//    
//    var isCollapsible: Bool = false
//    var isCollapsed: Bool = false
//    var email: String
//    
//    init(email: String) {
//        self.email = email
//    }
//}
//
//class ItemAttribute: ItemBaseModel {
//    var rowCount: Int = 0
//    
//    var type: ItemType = .attribute
//    var sectionTitle: String = "Price (USD)"
//    var isCollapsible: Bool = false
//    var isCollapsed: Bool = false
//    
//    var attributes: [ProfileAttribute]
//    
//    init(attributes: [ProfileAttribute]) {
//        self.attributes = attributes
//        self.rowCount = attributes.count
//    }
//}

//class AppSearchProductMainFilter: ItemBaseModel {
//    var rowCount: Int = 5
//    
//    var type: ItemType = .mainfilter
//    var sectionTitle: String = "AppProductMainFilterSection"
//    
//    var isCollapsible: Bool = false
//    var isCollapsed: Bool = false
//    
//    var filtersItems: [CollpasedMenuPrepare]
//    init(filtersValues: [CollpasedMenuPrepare]) {
//        self.filtersItems = filtersValues
//        self.rowCount = filtersValues.count
//    }
//}
//
//class ItemRating: ItemBaseModel {
//    var rowCount: Int = 0
//    
//    var type: ItemType = .rating
//    var sectionTitle: String = "Rating"
//    
//    var isCollapsible: Bool = false
//    var isCollapsed: Bool = false
//    
//    var rating: [Rating]
//    
//    init(rating: [Rating]) {
//        self.rating = rating
//        self.rowCount = rating.count
//    }
//}
//
//class ItemExpand: ItemBaseModel {
//    var rowCount: Int = 0
//    
//    var type: ItemType = .expand
//    var sectionTitle: String = "Colors"
//    
//    var isCollapsible: Bool = false
//    var isCollapsed: Bool = false
//    
//    var expandRating: [Expand]
//    
//    init(expandRating: [Expand]) {
//        self.expandRating = expandRating
//        self.rowCount = expandRating.count
//    }
//}
