//
//  RecommendResponse.swift
//  FBSnapshotTestCase
//
//  Created by Арсений Дорогин on 31.07.2020.
//

import Foundation

public struct RecommenderResponse {
    // TODO
    var recommended: [String] ///products ids array
    var title: String ///title block recommendation
    
    init(json: [String:Any]) {
        self.recommended = json["recommends"] as! [String]
        self.title = json["title"] as! String
    }
}
