//
//  ProbabilityToPurchaseResponse.swift
//  REES46
//

import Foundation

public struct ProbabilityToPurchaseResponse {
    public let probability: Double
    public let clientId: String

    init?(json: [String: Any]) {
        guard let probVal = json["probability"] else { return nil }
        let probability: Double
        if let d = probVal as? Double {
            probability = d
        } else if let n = probVal as? NSNumber {
            probability = n.doubleValue
        } else {
            return nil
        }
        if let cid = json["client_id"] as? String {
            self.clientId = cid
        } else if let cidNum = json["client_id"] as? NSNumber {
            self.clientId = cidNum.stringValue
        } else {
            return nil
        }
        self.probability = probability
    }
}
