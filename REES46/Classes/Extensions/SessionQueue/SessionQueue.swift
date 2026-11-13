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

/// A shop's request queue. While the shop has no device id the queue is closed: requests added then
/// — and the ones queued earlier that have not started — wait, and go out once the queue opens with
/// the id `/init` brought. Opened, requests run as they come. The check is made when a request starts,
/// not when it is added, so one queued behind an `/init` that `deleteUserCredentials` replaced waits for
/// the new `/init`, not for the old one. Operations (the `/init` itself) are never held: they are what
/// opens the queue.
final class ShopSessionQueue: SessionQueue {

    private let lock = NSLock()
    private var closed = false
    private var held: [() -> Void] = []

    /// Requests that start from now on wait until `open()`.
    func close() {
        lock.lock()
        closed = true
        lock.unlock()
    }

    /// Lets the held requests and the later ones go.
    func open() {
        lock.lock()
        closed = false
        let waiting = held
        held.removeAll()
        lock.unlock()
        waiting.forEach { queue.addOperation($0) }
    }

    /// Whether requests wait; for tests.
    var isClosed: Bool {
        lock.lock(); defer { lock.unlock() }
        return closed
    }

    override func addOperation(_ operation: @escaping () -> Void) {
        queue.addOperation { [weak self] in
            guard let self = self else { return operation() }
            self.runOrHold(operation)
        }
    }

    override func addOperation(_ operation: Operation) {
        super.addOperation(operation)
    }

    private func runOrHold(_ operation: @escaping () -> Void) {
        lock.lock()
        if closed {
            held.append { [weak self] in
                guard let self = self else { return operation() }
                self.runOrHold(operation)
            }
            lock.unlock()
            return
        }
        lock.unlock()
        operation()
    }
}
