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

/// A shop's request queue. While the shop has no device id the queue is closed: every request added
/// then waits in the queue — `operationCount`, `operations`, `cancelAll()` and
/// `waitUntilAllOperationsAreFinished()` see it — and goes once the queue opens, after `/init` brought
/// the id and its completion ran, as it always has. Opened, requests run as they come. A request that
/// starts while the queue is closed — queued just before `deleteUserCredentials` closed it — waits for
/// the next `/init` too. The init operation itself is never held: it is what opens the queue.
final class ShopSessionQueue: SessionQueue {

    private let lock = NSLock()
    /// While closed: what the requests added meanwhile depend on; `open()` runs it.
    private var gate: Operation?
    /// Requests that started while the queue was closed; they go again once it opens.
    private var held: [() -> Void] = []

    /// Requests added from now on wait until `open()`; a queue closed already stays closed.
    func close() {
        lock.lock()
        if gate == nil {
            gate = BlockOperation {}
        }
        lock.unlock()
    }

    /// Lets the waiting requests and the later ones go.
    func open() {
        lock.lock()
        let opening = gate
        gate = nil
        let waiting = held
        held.removeAll()
        lock.unlock()
        opening.map(queue.addOperation)
        waiting.forEach(addOperation)
    }

    /// Whether requests wait; for tests.
    var isClosed: Bool {
        lock.lock(); defer { lock.unlock() }
        return gate != nil
    }

    override func addOperation(_ operation: @escaping () -> Void) {
        addOperation(BlockOperation { [weak self] in
            guard let self = self else { return operation() }
            self.runOrHold(operation)
        })
    }

    /// An operation of the app waits for the device id too, as it always has.
    override func addOperation(_ operation: Operation) {
        lock.lock()
        if let gate = gate, gate !== operation {
            operation.addDependency(gate)
        }
        lock.unlock()
        super.addOperation(operation)
    }

    /// The init operation: never held.
    func addInitOperation(_ operation: Operation) {
        queue.addOperation(operation)
    }

    private func runOrHold(_ operation: @escaping () -> Void) {
        lock.lock()
        if gate != nil {
            held.append(operation)
            lock.unlock()
            return
        }
        lock.unlock()
        operation()
    }
}
