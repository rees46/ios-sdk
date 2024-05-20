import Foundation

public class GenericDataTask<T: Decodable>: SessionDataTaskProtocol {
    
    public var sessionTask: URLSessionTask
    public var sessionData: Data?
    public let sessionIdentifier: Int
    
    public init(sessionTask: URLSessionTask, sessionData: Data? = nil, sessionIdentifier: Int? = nil) {
        self.sessionTask = sessionTask
        self.sessionData = sessionData
        self.sessionIdentifier = sessionIdentifier ?? sessionTask.taskIdentifier
    }
    
    public var sessionTaskElement: T? {
        return sessionDecodable as? T
    }
    
    public var sessionTaskElements: [T] {
        return sessionDecodables as? [T] ?? []
    }
    
    public var sessionDecodable: Decodable? {
        do {
            guard let sessionData = sessionData else {
                return nil
            }
            
            return try JSONDecoder().decode(T.self, from: sessionData)
        } catch let error {
            debugPrint(error)
            return nil
        }
    }
    
    public var sessionDecodables: [Decodable] {
        do {
            guard let data = sessionData else {
                return []
            }
            
            return try JSONDecoder().decode([T].self, from: data)
        } catch let error {
            debugPrint(error)
            return []
        }
    }
    
    public func sessionUpdate(newData: Data) -> SessionDataTaskProtocol {
        sessionData = sessionUpdate(data: sessionData, newData: newData)
        return self
    }
    
}
