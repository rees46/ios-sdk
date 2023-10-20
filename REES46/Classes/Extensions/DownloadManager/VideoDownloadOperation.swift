import Foundation
import AVFoundation

class VideoDownloadOperation : VideoAsyncOperation {
    
    public var task: URLSessionTask!
    public var taskSlideIdentifier: String!
    
    init(session: URLSession, url: URL, videoSlideId: String) {
        task = session.downloadTask(with: url)
        taskSlideIdentifier = videoSlideId
        super.init()
    }

    override func cancel() {
        task.cancel()
        super.cancel()
        
        completeOperation()
    }

    override func main() {
        task.resume()
    }
}

extension VideoDownloadOperation {
    
    func trackDownloadByOperation(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let manager = FileManager.default
            let destinationURL = try manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(downloadTask.originalRequest!.url!.lastPathComponent)
            
            if manager.fileExists(atPath:  destinationURL.path) {
                try manager.removeItem(at: destinationURL)
            }
            //print(destinationURL.absoluteString)
            
            try manager.moveItem(at: location, to: destinationURL)
            
            let duration = AVURLAsset(url: destinationURL).duration.seconds
            let vTime = String(format:"%d", Int(duration.truncatingRemainder(dividingBy: 60)))
            //print(vTime)
            
            DispatchQueue.main.async {
                SdkGlobalHelper.sharedInstance.saveVideoParamsToDictionary(parentSlideId: self.taskSlideIdentifier, paramsDictionary: [self.taskSlideIdentifier : vTime])
            }
        } catch {
            //print("\(error)")
        }
        
        completeOperation()
    }
    
    func trackDownloadByOperation(_ session: URLSession, sdkDownloadVideoTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        //let progress = Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)
        //print("\(sdkDownloadVideoTask.originalRequest!.url!.absoluteString) \(progress)")
    }
    
    func trackDownloadByOperation(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            print("\(String(describing: error))")
        }
        
        completeOperation()
    }
}

