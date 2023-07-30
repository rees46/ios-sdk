import Foundation
import UIKit

public struct StoryCellImageCache {
    enum Error: Swift.Error {
        case StoryCellImageCacheSaveError
    }
    
    public static var log: ((_ message: String, _ file: String, _ function: String, _ line: Int) -> Void)?
    
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
            log?("SDK Got image for \(key) from in-memory cache", file, function, line)
            dispatchCompletionOnMain(image)
            
        } else if let image = fileSystemImage(for: key) {
            inMemory(save: image, for: key)
            log?("SDK Got image for \(key) from file system", file, function, line)
            dispatchCompletionOnMain(image)
            
        } else {
            if let imageURLProvider = imageURLProvider, let url = imageURLProvider.url(for: key) {
                let dataTask = urlSession.dataTask(with: url, completionHandler: { (data, response, error) in
                    if let data = data, let image = UIImage(data: data) {
                        save(image, for: key)
                        dispatchCompletionOnMain(image)
                    } else {
                        if let error = error, (error as NSError).code != -999 {
                            log?("SDK Error downloading image for key \(key): \(error)", file, function, line)
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
            log?("SDK Error saving image for key \(key): \(error)", file, function, line)
        }
    }
    
    public static func cancelAllDownloads() {
        urlSession.invalidateAndCancel()
        urlSession = createUrlSession()
    }

    
    fileprivate static var shared = StoryCellImageCache()
    fileprivate let cache = NSCache<AnyObject, AnyObject>()
    fileprivate static let cacheDirectory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first

    fileprivate init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: self, queue: OperationQueue.current) { (note) in
            StoryCellImageCache.purgeNSCache()
        }
    }

    fileprivate static func purgeNSCache(file: String = #file, function: String = #function, line: Int = #line) {
        log?("SDK Purged NSCache", file, function, line)
        StoryCellImageCache.shared.cache.removeAllObjects()
    }

    fileprivate static func inMemoryImage(for key: String) -> UIImage? {
        if let image = StoryCellImageCache.shared.cache.object(forKey: key as NSString) as? UIImage {
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
        StoryCellImageCache.shared.cache.setObject(image, forKey: key as AnyObject)
    }

    fileprivate static func fileSystem(save image: UIImage, for key: String, file: String = #file, function: String = #function, line: Int = #line) throws {
        if let jpeg = image.jpegData(compressionQuality: 1.0), let url = fileUrl(forKey: key) {
            do {
                try jpeg.write(to: url, options: [.atomic])
            } catch {
                log?("SDK Error saving image to filesystem for \(key) - \(error)", file, function, line)
                throw Error.StoryCellImageCacheSaveError
            }
        }
        throw Error.StoryCellImageCacheSaveError
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
        let task = StoryCellImageCache.image(for: key, file: file, function: function, line: line) { image in
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
