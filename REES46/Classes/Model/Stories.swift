import Foundation

public struct StoriesResponse {
    public var stories: [Story]
    
    public init(json: [String: Any]) {
        let storiesJSON = json["stories"] as? [[String: Any]] ?? []
        self.stories = storiesJSON.map({Story(json: $0)})
    }
}

public struct Story {
    public var id: Int
    public var name: String
    public var avatar: String
    public var viewed: Bool
    public var startPosition: Int
    public var slides: [StorySlide]
    
    public init(json: [String: Any]) {
        self.id = json["id"] as? Int ?? 0
        self.avatar = json["avatar"] as? String ?? ""
        self.viewed = json["viewed"] as? Bool ?? false
        self.startPosition = json["start_position"] as? Int ?? 0
        let slidesJSON = json["slides"] as? [[String: Any]] ?? []
        self.slides = slidesJSON.map({StorySlide(json: $0)})
        self.name = json["name"] as? String ?? ""
    }
}

public struct StorySlide {
    public var id: Int
    public var background: String
    public var type: String
    public var elements: [StoryElement]
    
    public init(json: [String: Any]) {
        self.id = json["id"] as? Int ?? 0
        self.background = json["background"] as? String ?? ""
        self.type = json["type"] as? String ?? ""
        let elementsJSON = json["elements"] as? [[String: Any]] ?? []
        self.elements = elementsJSON.map({StoryElement(json: $0)})
    }
}

public struct StoryElement {
    public var type: String
    public var link: String
    public var title: String?
    public var background: String?
    
    public init(json: [String: Any]) {
        self.type = json["type"] as? String ?? ""
        self.link = json["link"] as? String ?? ""
        self.title = json["title"] as? String
        self.background = json["background"] as? String
    }
}
