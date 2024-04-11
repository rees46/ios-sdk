import Foundation

public func dataFromFile(_ filename: String) -> Data? {
    @objc class TestClass: NSObject { }
    
    let bundle = Bundle(for: TestClass.self)
    if let path = bundle.path(forResource: filename, ofType: "json") {
        return (try? Data(contentsOf: URL(fileURLWithPath: path)))
    }
    return nil
}

class DataResponse: Codable {
    let data: DataContent
    let error: Int
    let message: String
    
    init(data: DataContent, error: Int, message: String) {
        self.data = data
        self.error = error
        self.message = message
    }
}

class DataContent: Codable {
    let id: Int
    let fullName, pictureURL, email, about: String?
    let filters: [CpllpasedMenuPrepare]
    let rating: [Rating]
    let expand: [Expand]
    let profileAttributes: [ProfileAttribute]
    
    enum CodingKeys: String, CodingKey {
        case id, fullName
        case pictureURL = "pictureUrl"
        case email, about, filters, rating, expand, profileAttributes
    }
    
    init(id: Int, fullName: String, pictureURL: String, email: String, about: String, filters: [CpllpasedMenuPrepare], rating: [Rating], expand: [Expand], profileAttributes: [ProfileAttribute]) {
        self.id = id
        self.fullName = fullName
        self.pictureURL = pictureURL
        self.email = email
        self.about = about
        self.filters = filters
        self.rating = rating
        self.expand = expand
        self.profileAttributes = profileAttributes
    }
}

class CpllpasedMenuPrepare: Codable {
    var id: String = ""
    var title: String = ""
    var titleValues: [String] = [""]
    var selected = false
    
    init(id: String, title: String, titleValues: [String], selected: Bool) {
        self.id = id
        self.title = title
        self.titleValues = titleValues
        self.selected = selected
    }
    
    static func fetch()->[CpllpasedMenuPrepare]{
        let menuList = [CpllpasedMenuPrepare(id: "A1", title: "A1", titleValues: ["A1"], selected: true)]
        return menuList
    }
}

class Friend: Codable {
    let name, pictureURL: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case pictureURL = "pictureUrl"
    }
    
    init(name: String, pictureURL: String) {
        self.name = name
        self.pictureURL = pictureURL
    }
}

class Rating: Codable {
    let name, pictureURL: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case pictureURL = "pictureUrl"
    }
    
    init(name: String, pictureURL: String) {
        self.name = name
        self.pictureURL = pictureURL
    }
}

class ProfileAttribute: Codable {
    let key, value: String
    
    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

class Expand: Codable {
    let name, pictureURL: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case pictureURL = "pictureUrl"
    }
    
    init(name: String, pictureURL: String) {
        self.name = name
        self.pictureURL = pictureURL
    }
}
