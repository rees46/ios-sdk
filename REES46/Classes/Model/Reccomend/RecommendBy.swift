import Foundation

public class RecomendedBy {
  
  var code: String = ""
  var type: RecommendedByCase = .chain
  
  public init(type: RecommendedByCase, code: String) {
    self.type = type
    self.code = code
  }
  
  func getParams() -> [String: String] {
    let params = [
      Constants.RecommendedBy.recommendedBy: type.rawValue,
      type.getCodeField(): code
    ]
    return params
  }
}

public enum RecommendedByCase: String {
  case dynamic = "dynamic"
  case chain = "chain"
  case transactional = "transactional"
  case fullSearch = "full_search"
  case instantSearch = "instant_search"
  case bulk = "bulk"
  case webPushDigest = "web_push_digest"
  
  func getCodeField() -> String {
    switch self {
    case .webPushDigest:
      return Constants.RecommendedBy.webPushDigestCode
    default:
      return Constants.RecommendedBy.recommendedCode
    }
  }
}
