import UIKit

class SDDownloadObject: NSObject {

    var completionBlock: RRDownloadManager.DownloadCompletionBlock
    var progressBlock: RRDownloadManager.DownloadProgressBlock?
    let downloadTask: URLSessionDownloadTask
    let directoryName: String?
    let fileName:String?
    
    init(downloadTask: URLSessionDownloadTask,
         progressBlock: RRDownloadManager.DownloadProgressBlock?,
         completionBlock: @escaping RRDownloadManager.DownloadCompletionBlock,
         fileName: String?,
         directoryName: String?) {
        
        self.downloadTask = downloadTask
        self.completionBlock = completionBlock
        self.progressBlock = progressBlock
        self.fileName = fileName
        self.directoryName = directoryName
    }
    
}
