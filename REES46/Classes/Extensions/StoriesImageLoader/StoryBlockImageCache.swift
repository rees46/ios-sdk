import Foundation
import UIKit

public struct StoryBlockImageCache {
    enum Error: Swift.Error {
        case StoryBlockImageCacheSaveError
    }
    
    public static var internalLogger: ((_ message: String, _ file: String, _ function: String, _ line: Int) -> Void)?
    
    public static var imageURLProvider: StoryImageURLProviding?

    fileprivate static var urlSession: URLSession = createUrlSession()
    fileprivate static func createUrlSession() -> URLSession {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        return session
    }

    @discardableResult public static func image(for key: String, file: String = #file, function: String = #function, line: Int = #line, completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        let dispatchCompletionOnMain: (UIImage?) -> Void = { image in
            DispatchQueue.main.async {
                completion(image)
            }
        }

        if let image = inMemoryImage(for: key) {
            dispatchCompletionOnMain(image)
            
        } else if let image = fileSystemImage(for: key) {
            inMemory(save: image, for: key)
            dispatchCompletionOnMain(image)
            
        } else {
            if let imageURLProvider = imageURLProvider, let url = imageURLProvider.url(for: key) {
                let dataTask = urlSession.dataTask(with: url, completionHandler: { (data, response, error) in
                    if let data = data, let image = UIImage(data: data) {
                        save(image, for: key)
                        dispatchCompletionOnMain(image)
                    } else {
                        if let error = error, (error as NSError).code != -999 {
                            print("SDK Error downloading image for block")
                        }
                        dispatchCompletionOnMain(nil)
                    }
                })
                dataTask.resume()
                return dataTask

            } else {
                dispatchCompletionOnMain(nil)
            }
        }

        return nil
    }
    
    public static func save(_ image: UIImage, for key: String, file: String = #file, function: String = #function, line: Int = #line) -> Void {
        inMemory(save: image, for: key)
        do {
            try fileSystem(save: image, for: key)
        } catch {
            internalLogger?("Sdk Internal Error saving image for key \(key): \(error)", file, function, line)
            //print("SDK Error saving image for block")
        }
    }
    
    public static func cancelAllDownloads() {
        urlSession.invalidateAndCancel()
        urlSession = createUrlSession()
    }
    
    //fileprivate static var internalShared = StoryBlockImageCache()
    //fileprivate let cache = NSCache<AnyObject, AnyObject>()
    public static var shared = StoryBlockImageCache()
    public let internalCache = NSCache<AnyObject, AnyObject>()
    fileprivate static let cacheDirectory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first

    fileprivate init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: self, queue: OperationQueue.current) { (note) in
            StoryBlockImageCache.purgeRecursiveNSCache()
        }
    }

    fileprivate static func purgeRecursiveNSCache(file: String = #file, function: String = #function, line: Int = #line) {
        StoryBlockImageCache.shared.internalCache.removeAllObjects()
    }

    fileprivate static func inMemoryImage(for key: String) -> UIImage? {
        if let image = StoryBlockImageCache.shared.internalCache.object(forKey: key as NSString) as? UIImage {
            return image
        } else {
            return nil
        }
    }

    fileprivate static func fileSystemImage(for key: String) -> UIImage? {
        if let url = fileUrl(forKey: key),
            let data = try? Data(contentsOf: url),
            let image = UIImage(data: data) {
            return image
        }

        return nil
    }

    fileprivate static func inMemory(save image: UIImage, for key: String) {
        StoryBlockImageCache.shared.internalCache.setObject(image, forKey: key as AnyObject)
    }

    fileprivate static func fileSystem(save image: UIImage, for key: String, file: String = #file, function: String = #function, line: Int = #line) throws {
//        if let jpeg = image.jpegData(compressionQuality: 1.0), let url = fileUrl(forKey: key) {
//            do {
//                try jpeg.write(to: url, options: [.atomic])
//            } catch {
//                internalLogger?("Error saving image to filesystem for \(key) - \(error)", file, function, line)
//                throw Error.StoryBlockImageCacheSaveError
//            }
//        }
        
        if let pngAlphaQuality = image.pngData() , let url = fileUrl(forKey: key) {
            do {
                try pngAlphaQuality.write(to: url, options: [.atomic])
            } catch {
                throw Error.StoryBlockImageCacheSaveError
            }
        }
        throw Error.StoryBlockImageCacheSaveError
    }

    fileprivate static func fileUrl(forKey key: String) -> URL? {
        if let cacheDirectory = cacheDirectory {
            let safeKey = key.replacingOccurrences(of: "/", with: "-")
            return cacheDirectory.appendingPathComponent("\(safeKey).jpg", isDirectory: false)
        }
        return nil
    }
}

public protocol StoryImageURLProviding {
    func url(for key: String) -> URL?
}

private var imageTaskKey: Void?
public extension UIImageView {
    func setStoryImage(for key: String, file: String = #file, function: String = #function, line: Int = #line) {
        let task = StoryBlockImageCache.image(for: key, file: file, function: function, line: line) { image in
            self.image = image
        }
        setImageTask(task)
    }

    func cancelStoryImageDownload() {
        imageDataTask?.cancel()
        setImageTask(nil)
    }

    fileprivate var imageDataTask: URLSessionDataTask? {
        return objc_getAssociatedObject(self, &imageTaskKey) as? URLSessionDataTask
    }

    fileprivate func setImageTask(_ task: URLSessionDataTask?) {
        objc_setAssociatedObject(self, &imageTaskKey, task, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
