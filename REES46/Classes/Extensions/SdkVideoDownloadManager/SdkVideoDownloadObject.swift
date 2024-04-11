import UIKit

class SdkVideoDownloadObject: NSObject {

    var completionBlock: SdkVideoDownloadManager.DownloadCompletionBlock
    var progressBlock: SdkVideoDownloadManager.DownloadProgressBlock?
    let downloadTask: URLSessionDownloadTask
    let directoryName: String?
    let fileName:String?
    
    init(downloadTask: URLSessionDownloadTask,
         progressBlock: SdkVideoDownloadManager.DownloadProgressBlock?,
         completionBlock: @escaping SdkVideoDownloadManager.DownloadCompletionBlock,
         fileName: String?,
         directoryName: String?) {
        
        self.downloadTask = downloadTask
        self.completionBlock = completionBlock
        self.progressBlock = progressBlock
        self.fileName = fileName
        self.directoryName = directoryName
    }
    
}
