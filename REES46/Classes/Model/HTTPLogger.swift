import Foundation

public protocol HTTPLoggerConfigurationType {
    var bodyTrimLength: Int { get }
    func printLog(_ string: String)
    func enableCapture(_ request: URLRequest) -> Bool
}

extension HTTPLoggerConfigurationType {
    
    public var bodyTrimLength: Int {
        return 10000
    }
    
    public func printLog(_ string: String) {
        if global_EL {
            print(string)
        }
    }
    
    public func enableCapture(_ request: URLRequest) -> Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
}

public struct HTTPLoggerDefaultConfiguration: HTTPLoggerConfigurationType {
    
}

public final class HTTPLogger: URLProtocol, URLSessionDelegate {
    
    // MARK: - Public
    
    public static var configuration: HTTPLoggerConfigurationType = HTTPLoggerDefaultConfiguration()
    
    public class func register() {
        URLProtocol.registerClass(self)
    }
    
    public class func unregister() {
        URLProtocol.unregisterClass(self)
    }
    
    public class func defaultSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.protocolClasses?.insert(HTTPLogger.self, at: 0)
        return config
    }
    
    //MARK: - NSURLProtocol
    
    public override class func canInit(with request: URLRequest) -> Bool {
        
        guard HTTPLogger.configuration.enableCapture(request) == true else {
            return false
        }
        
        guard self.property(forKey: requestHandledKey, in: request) == nil else {
            return false
        }
        
        return true
    }
    
    
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    public override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, to: b)
    }
    
    public override func startLoading() {
        guard let req = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest, newRequest == nil else { return }
        
        self.newRequest = req
        
        HTTPLogger.setProperty(true, forKey: HTTPLogger.requestHandledKey, in: newRequest!)
        HTTPLogger.setProperty(Date(), forKey: HTTPLogger.requestTimeKey, in: newRequest!)
        
        let session = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        
        session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                self.logError(error as NSError)
                
                return
            }
            guard let response = response, let data = data else { return }
            
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: URLCache.StoragePolicy.allowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
            self.logResponse(response, data: data)
            }) .resume()
        
        logRequest(newRequest! as URLRequest)
    }
    
    public override func stopLoading() {
    }
    
    func URLSession(
        _ session: Foundation.URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
                                   newRequest request: URLRequest,
                                              completionHandler: (URLRequest?) -> Void) {
        
        self.client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        
    }
    
    
    //MARK: - Logging
    
    public func logError(_ error: Error) {
        
        var logString = "⚠️\n"
        logString += "Error: \n\(error.localizedDescription)\n"
        
        logString += "\n\n*************************\n\n"
        HTTPLogger.configuration.printLog(logString)
    }
    
    public func logRequest(_ request: URLRequest) {
        var logString = "\n📤"
        if let url = request.url?.absoluteString {
            logString += "Request: \n  \(request.httpMethod ?? "POST") \(url)\n"
        }
        
        if let headers = request.allHTTPHeaderFields {
            logString += "Header:\n"
            logString += logHeaders(headers as [String : AnyObject]) + "\n"
        }
        
        if let data = request.httpBody,
            let bodyString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            
            logString += "Body:\n"
            logString += trimTextOverflow(bodyString as String, length: HTTPLogger.configuration.bodyTrimLength)
        }
        
        if let dataStream = request.httpBodyStream {
            
            let bufferSize = 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            
            let data = NSMutableData()
            dataStream.open()
            while dataStream.hasBytesAvailable {
                let bytesRead = dataStream.read(&buffer, maxLength: bufferSize)
                data.append(buffer, length: bytesRead)
            }
            
            if let bodyString = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue) {
                logString += "Body:\n"
                logString += trimTextOverflow(bodyString as String, length: HTTPLogger.configuration.bodyTrimLength)
            }
        }
        
        logString += "\n\n*************************\n\n"
        HTTPLogger.configuration.printLog(logString)
    }
    
    public func logResponse(_ response: URLResponse, data: Data? = nil) {
        
        var logString = "\n📥"
        if let url = response.url?.absoluteString {
            logString += "Response: \n  \(url)\n"
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            let localisedStatus = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode).capitalized
            logString += "Status: \n  \(httpResponse.statusCode) - \(localisedStatus)\n"
        }
        
        if let headers = (response as? HTTPURLResponse)?.allHeaderFields as? [String: AnyObject] {
            logString += "Header: \n"
            logString += self.logHeaders(headers) + "\n"
        }
        guard let data = data else { return }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            let pretty = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            
            if let string = NSString(data: pretty, encoding: String.Encoding.utf8.rawValue) {
                logString += "\nJSON: \n\(string)"
            }
        }
        catch {
            if let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                logString += "\nData: \n\(string)"
            }
        }
        
        logString += "\n\n*************************\n\n"
        HTTPLogger.configuration.printLog(logString)
    }
    
    public func logHeaders(_ headers: [String: AnyObject]) -> String {
        
        let string = headers.reduce(String()) { str, header in
            let string = "  \(header.0) : \(header.1)"
            return str + "\n" + string
        }
        let logString = "[\(string)\n]"
        return logString
    }
    
    // MARK: - Private
    
    fileprivate static let requestHandledKey = "RequestLumberjackHandleKey"
    fileprivate static let requestTimeKey = "RequestLumberjackRequestTime"
    
    fileprivate var data: NSMutableData?
    fileprivate var response: URLResponse?
    fileprivate var newRequest: NSMutableURLRequest?
    
    fileprivate func trimTextOverflow(_ string: String, length: Int) -> String {
        
        guard string.count > length else {
            return string
        }
        
        return string.substring(to: string.index(string.startIndex, offsetBy: length)) + "…"
    }
}
