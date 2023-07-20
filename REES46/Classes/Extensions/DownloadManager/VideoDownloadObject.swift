import UIKit

class SDDownloadObject: NSObject {

    var completionBlock: VideoDownloadManager.DownloadCompletionBlock
    var progressBlock: VideoDownloadManager.DownloadProgressBlock?
    let downloadTask: URLSessionDownloadTask
    let directoryName: String?
    let fileName:String?
    
    init(downloadTask: URLSessionDownloadTask,
         progressBlock: VideoDownloadManager.DownloadProgressBlock?,
         completionBlock: @escaping VideoDownloadManager.DownloadCompletionBlock,
         fileName: String?,
         directoryName: String?) {
        
        self.downloadTask = downloadTask
        self.completionBlock = completionBlock
        self.progressBlock = progressBlock
        self.fileName = fileName
        self.directoryName = directoryName
    }
    
}
