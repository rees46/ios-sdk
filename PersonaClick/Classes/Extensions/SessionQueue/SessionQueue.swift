import Foundation

open class SessionQueue {
    
    public static let manager: SessionQueue = SessionQueue(name: "datatasks.sessionQueue")
    
    //Sample usage with parameters
    //private let sessionQueue = SessionQueue.manager
    //private let sessionQueue = SessionQueue(name: "datatasks.sessionQueue")
    //private let sessionQueue = SessionQueue(name: "datatasks.sessionQueue", maxConcurrentOperationCount: 100)
    
    public var operationCount: Int {
        return self.queue.operationCount
    }
    
    public var operations: [Operation] {
        return self.queue.operations
    }
    
    public var qos: QualityOfService {
        return .background
    }
    
    public var maxConcurrentOperationCount: Int {
        get {
            return self.queue.maxConcurrentOperationCount
        }
        set {
            self.queue.maxConcurrentOperationCount = newValue
        }
    }
    
    public var isExecuting: Bool {
        return !self.queue.isSuspended
    }
    
    public let queue: OperationQueue = OperationQueue()
    
    public init(name: String, maxConcurrentOperationCount: Int = Int.max) {
        self.queue.name = name
        self.maxConcurrentOperationCount = maxConcurrentOperationCount
    }
    
    public func addOperation(_ operation: @escaping () -> Void) {
        self.queue.addOperation(operation)
    }
    
    public func addOperation(_ operation: Operation) {
        self.queue.addOperation(operation)
    }
    
    public func addListOfOperations(_ operations: [Operation], completionHandler: (() -> Void)? = nil) {
        for (index, operation) in operations.enumerated() {
            if index > 0 {
                operation.addDependency(operations[index - 1])
            }
            
            self.addOperation(operation)
        }
        
        guard let completionHandler = completionHandler else {
            return
        }
        
        let completionOperation = BlockOperation(block: completionHandler)
        if !operations.isEmpty {
            completionOperation.addDependency(operations[operations.count - 1])
        }
        self.addOperation(completionOperation)
    }
    
    public func addListOfOperations(_ operations: Operation..., completionHandler: (() -> Void)? = nil) {
        self.addListOfOperations(operations, completionHandler: completionHandler)
    }
    
    public func cancelAll() {
        self.queue.cancelAllOperations()
    }
    
    public func pause() {
        self.queue.isSuspended = true
        
        for operation in self.queue.operations where operation is SessionOperation {
            (operation as? SessionOperation)?.pause()
        }
    }
    
    public func resume() {
        self.queue.isSuspended = false
        
        for operation in self.queue.operations where operation is SessionOperation {
            (operation as? SessionOperation)?.resume()
        }
    }
    
    public func waitUntilAllOperationsAreFinished() {
        self.queue.waitUntilAllOperationsAreFinished()
    }
}
