//
//  Stories.swift
//  REES46
//
//  Created by Arseniy Dorogin on 16.08.2022.
//

import Foundation

public struct StoriesResponse {
    var stories: [Story]
    
    init(json: [String: Any]) {
        let storiesJSON = json["stories"] as? [[String: Any]] ?? []
        self.stories = storiesJSON.map({Story(json: $0)})
    }
}

public struct Story {
    var id: Int
    var name: String
    var avatar: String
    var viewed: Bool
    var startPosition: Int
    var slides: [StorySlide]
    
    init(json: [String: Any]) {
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
    var id: Int
    var background: String
    var type: String
    var elements: [StoryElement]
    
    init(json: [String: Any]) {
        self.id = json["id"] as? Int ?? 0
        self.background = json["background"] as? String ?? ""
        self.type = json["type"] as? String ?? ""
        let elementsJSON = json["elements"] as? [[String: Any]] ?? []
        self.elements = elementsJSON.map({StoryElement(json: $0)})
    }
}

public struct StoryElement {
    var type: String
    var link: String
    var title: String?
    var background: String?
    
    init(json: [String: Any]) {
        self.type = json["type"] as? String ?? ""
        self.link = json["link"] as? String ?? ""
        self.title = json["title"] as? String
        self.background = json["background"] as? String
    }
}
