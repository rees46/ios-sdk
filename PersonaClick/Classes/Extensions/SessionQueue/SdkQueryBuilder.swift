import Foundation

internal struct SdkQueryBuilder {
    
    internal static func build(query: [String: String]) -> String {
        var finalCombinatedQuery: String = ""
        for (index, parameter) in query.enumerated() {
            guard let parameterKey = parameter.key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed), let parameterValue = parameter.value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
                continue
            }
            
            finalCombinatedQuery += index == 0 ? "?" : "&"
            finalCombinatedQuery += parameterKey + "=" + parameterValue
        }
        return finalCombinatedQuery
    }
}
