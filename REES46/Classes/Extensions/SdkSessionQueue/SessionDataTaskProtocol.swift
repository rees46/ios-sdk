import Foundation

public protocol SessionDataTaskProtocol {
    var sessionTask: URLSessionTask { get }
    var sessionData: Data? { get }
    var sessionIdentifier: Int { get }
    var sessionDecodable: Decodable? { get }
    var sessionDecodables: [Decodable] { get }
    func sessionUpdate(newData: Data) -> SessionDataTaskProtocol
    func sessionUpdate(data: Data? , newData: Data) -> Data
}

extension SessionDataTaskProtocol {
    
    public func sessionUpdate(data: Data? , newData: Data) -> Data {
        if var currentData = data {
            currentData.append(newData)
            return currentData
        }
        
        return newData
    }
    
}
