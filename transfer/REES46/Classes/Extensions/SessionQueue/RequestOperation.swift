import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case options = "OPTIONS"
    case patch = "PATCH"
}

public class RequestOperation: SessionOperation {
    
    public enum RequestError: Error {
        case urlError
        case operationCancelled
    }
    
    public typealias RequestClosure = (Bool, HTTPURLResponse?, Data?, Error?) -> Void
    
    public static var globalCachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    
    private(set) public var task: URLSessionDataTask?
    
    private(set) public var url: URL?
    
    private(set) public var query: String = ""
    
    private(set) public var completeURL: URL?
    
    private(set) public var timeout: TimeInterval = 10
    
    private(set) public var cachePolicy: URLRequest.CachePolicy = globalCachePolicy
    
    private(set) public var method: HTTPMethod = .get
    private(set) public var headers: [String: String] = [:]
    private(set) public var body: Data = Data()
    
    private(set) public var completionHandler: RequestClosure?
    
    internal var session: URLSession {
        return URLSession.shared
    }
    
    private(set) public var request: URLRequest!
    
    private override init(executionBlock: (() -> Void)? = nil) {
        super.init(executionBlock: nil)
    }
    
    public convenience init(url: String, query: [String: String] = [:], timeout: TimeInterval = 10, method: HTTPMethod = .get, cachePolicy: URLRequest.CachePolicy = globalCachePolicy, headers: [String: String] = [:], sdkBody: Data = Data(), completionHandler: RequestClosure? = nil) {
        
        self.init()
        
        self.query = SdkQueryBuilder.build(query: query)
        
        self.url = URL(string: url)
        self.completeURL = URL(string: url + self.query)
        self.timeout = timeout
        self.method = method
        self.cachePolicy = cachePolicy
        self.headers = headers
        self.body = sdkBody
        self.completionHandler = completionHandler
    }
    
    public override func execute() {
        guard !self.isCancelled else {
            if let completionHandler = self.completionHandler {
                completionHandler(false, nil, nil, RequestError.operationCancelled)
            }
            
            self.finish()
            return
        }
        
        guard let url = self.completeURL else {
            if let completionHandler = self.completionHandler {
                completionHandler(false, nil, nil, RequestError.urlError)
            }
            
            self.finish()
            return
        }
        
        request = URLRequest(url: url, cachePolicy: self.cachePolicy, timeoutInterval: self.timeout)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        for header in self.headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        
        self.task = self.session.dataTask(with: request) { data, response, error in
            if let completionHandler = self.completionHandler {
                if let httpResponse = response as? HTTPURLResponse {
                    var error: Error? = error
                    let success: Bool = httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 && !self.isCancelled
                    
                    if self.isCancelled {
                        error = RequestError.operationCancelled
                    }
                    
                    completionHandler(success, httpResponse, data, error)
                } else {
                    completionHandler(false, nil, data, error)
                }
            }
            
            self.finish()
        }
        self.task?.resume()
    }
    
    public override func cancel() {
        super.cancel()
        
        self.task?.cancel()
    }
    
    public override func pause() {
        super.pause()
        
        self.task?.suspend()
    }
    
    public override func resume() {
        super.resume()
        
        self.task?.resume()
    }
}
