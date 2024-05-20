import Foundation

open class SessionOperation: Operation {
    public var executionBlock: (() -> Void)?
    
    public init(executionBlock: (() -> Void)? = nil) {
        super.init()
        self.executionBlock = executionBlock
    }
    
    open override var isAsynchronous: Bool {
        return true
    }
    
    private var _executing = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    open override var isExecuting: Bool {
        return _executing
    }
    
    private var _finished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }
    
    open override var isFinished: Bool {
        return _finished
    }
    
    open override func start() {
        _executing = true
        execute()
    }

    open func execute() {
        if let executionBlock = executionBlock {
            executionBlock()
            self.finish()
        }
    }

    public func finish() {
        _executing = false
        _finished = true
    }
    
    open func pause() {}
    
    open func resume() {}
    
    public func addToSharedQueuer() {
        SessionQueue.manager.addOperation(self)
    }
    
    public func addToQueue(_ queue: SessionQueue) {
        queue.addOperation(self)
    }
}
