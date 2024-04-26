import Foundation

struct Post: Codable {
    let userId: Int
    let id: Int
    let title: String
}

public class URLSessionQueue: NSObject, URLSessionDataDelegate {

    private let queue = DispatchQueue(label: "urlsession.datatasks.queue")

    private var dataTasks: [SessionDataTaskProtocol] = []
    
    public var taskCompleted: ((_ task: SessionDataTaskProtocol, _ error: Error?) -> Void)?
    
    public var allTasksCompletedHandler: ((_ tasks: [SessionDataTaskProtocol]) -> Void)?
    
    open var taskNeedNewBodyStream: ((URLSession, URLSessionTask) -> InputStream?)?
    
    open var taskNeedNewBodyStreamWithCompletion: ((URLSession, URLSessionTask, (InputStream?) -> Void) -> Void)?
    
    lazy var session: URLSession = {
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 3
        sessionConfiguration.waitsForConnectivity = true
        sessionConfiguration.shouldUseExtendedBackgroundIdleMode = true
        return URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
    }()
    
    public func addTask(dataTask: SessionDataTaskProtocol) {
        dataTasks.append(dataTask)
    }
    
    public func addTask<T: Decodable>(url: URL, lazy: Bool = true) -> GenericDataTask<T> {
        let task = createTask(url: url)
        let dataTask: GenericDataTask<T> = GenericDataTask(sessionTask: task)
        dataTasks.append(dataTask)
        return dataTask
    }
    
    public func addTask<T: Decodable>(request: URLRequest, lazy: Bool = true) -> GenericDataTask<T> {
        let task = createTask(request: request)
        let dataTask = GenericDataTask<T>(sessionTask: task)
        dataTasks.append(dataTask)
        return dataTask
    }
    
    public func createTask(url: URL) -> URLSessionDataTask {
        return session.dataTask(with: url)
    }
    
    public func createTask(request: URLRequest) -> URLSessionTask {
        return session.dataTask(with: request)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        if let completedTask = queue.sync(execute: {
            return dataTasks.first { $0.sessionTask.taskIdentifier == task.taskIdentifier }
        }) {
            taskCompleted?(completedTask, error)
        }
        
        let completed = queue.sync {
            return dataTasks.filter { $0.sessionTask.state == .completed }
        }
        
        let allTasks = queue.sync {
            return dataTasks.count
        }
        
        if completed.count == allTasks {
            queue.sync {
                allTasksCompletedHandler?(dataTasks)
            }
        } else {
            print("SDK: Tasks completed: \(completed.count)/\(dataTasks.count)")
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.sync {
            dataTasks = dataTasks.map { task in
                
                if task.sessionTask.taskIdentifier == dataTask.taskIdentifier {
                    return task.sessionUpdate(newData: data)
                }
                return task
            }
        }
    }
    
    public func execute(taskCompleted: ((_ task: SessionDataTaskProtocol, _ error: Error?) -> Void)? = nil, allTasksCompletedHandler: ((_ tasks: [SessionDataTaskProtocol]) -> Void)? = nil) {
        
        if let taskCompleted = taskCompleted {
            self.taskCompleted = taskCompleted
        }
        
        if let allTaskCompleted = allTasksCompletedHandler {
            self.allTasksCompletedHandler = allTaskCompleted
        }
        
        dataTasks.forEach { dataTask in
            dataTask.sessionTask.resume()
        }
    }
}
