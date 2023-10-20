import Foundation

enum VideoDownloadError: Error {
    case packetFetchError(String)
    case wrongOrder(String)
}

@objc protocol VideoDownloadProcessProtocol {
    
    func downloadingProgress(_ percent: Float, fileName: String)
    
    func sdkVideoDownloadSuccess(_ fileName: URL)

    func downloadWithError(_ error: Error?, fileName: String)
}


@objcMembers class VideoDownloadManager: NSObject {
    
    fileprivate var vOperations = [Int: VideoDownloadOperation]()
    
    public static var maxOperationCount = 1
    
    private let vQueue: OperationQueue = {
        let _queue = OperationQueue()
        _queue.name = "vDownloadManager"
        _queue.maxConcurrentOperationCount = maxOperationCount
        return _queue
    }()
    
    lazy var session: URLSession = {
        let vConfiguration = URLSessionConfiguration.default
        //let vConfiguration = URLSessionConfiguration.background(withIdentifier: "sdkBackgroundSession")
        vConfiguration.timeoutIntervalForRequest = 1
        vConfiguration.waitsForConnectivity = true
        return URLSession(configuration: vConfiguration, delegate: self, delegateQueue: nil)
    }()
    
    var parseProcessDelegate: VideoDownloadProcessProtocol?
    
    @discardableResult
    @objc func addDownload(_ url: URL, _ videoSlideId: String) -> VideoDownloadOperation {
        
        let operation = VideoDownloadOperation(session: session, url: url, videoSlideId: videoSlideId)
        vOperations[operation.task.taskIdentifier] = operation
        vQueue.addOperation(operation)
        
        return operation
    }

    func cancelAll() {
        vQueue.cancelAllOperations()
    }
}


extension VideoDownloadManager: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        vOperations[downloadTask.taskIdentifier]?.trackDownloadByOperation(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        
        if downloadTask.originalRequest!.url != nil {
            do {
                let manager = FileManager.default
                let destinationURL = try manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(downloadTask.originalRequest!.url!.lastPathComponent)
                parseProcessDelegate?.sdkVideoDownloadSuccess(destinationURL)
            } catch {
                //print("\(error)")
            }
            
//            DispatchQueue.main.async { [self] in
//                //parseProcessDelegate?.sdkVideoDownloadSuccess(downloadUrl)
//            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask sdkDownloadVideoTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        vOperations[sdkDownloadVideoTask.taskIdentifier]?.trackDownloadByOperation(session, sdkDownloadVideoTask: sdkDownloadVideoTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        
        if let downloadUrl = sdkDownloadVideoTask.originalRequest!.url {
            let percent = Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async { [self] in
                parseProcessDelegate?.downloadingProgress(Float(percent), fileName: downloadUrl.lastPathComponent)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let key = task.taskIdentifier
        vOperations[key]?.trackDownloadByOperation(session, task: task, didCompleteWithError: error)
        vOperations.removeValue(forKey: key)
        
        if let downloadUrl = task.originalRequest!.url, error != nil {
            DispatchQueue.main.async { [self] in
                parseProcessDelegate?.downloadWithError(error, fileName: downloadUrl.lastPathComponent)
            }
        }
    }
}
