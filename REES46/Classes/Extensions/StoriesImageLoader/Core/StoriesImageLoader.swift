import Foundation
import UIKit

public struct StoriesCollectionCellLoader {

    @discardableResult
    public static func request(with url: URLLiteralConvertible, onCompletion: @escaping (UIImage?, Error?, FetchOperation) -> Void) -> Loader? {
        guard let storiesCollectionCellLoaderUrl = url.storiesCollectionCellLoaderURL else { return nil }

        let task = Task(nil, onCompletion: onCompletion)
        let loader = StoriesCollectionCellLoader.session.getLoader(with: storiesCollectionCellLoaderUrl, task: task)
        loader.resume()

        return loader
    }

    static var session: StoriesCollectionCellLoader.Session {
        return Session.shared
    }

    static var manager: StoriesCollectionCellLoader.LoaderManager {
        return Session.manager
    }

    class Session: NSObject, URLSessionDataDelegate {
        
        static let shared = Session()
        static let manager = LoaderManager()

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard let loader = getLoader(with: dataTask) else { return }
            loader.operative.receiveData.append(data)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            guard let loader = getLoader(with: task) else { return }
            loader.complete(with: error)
        }

        func getLoader(with dataTask: URLSessionTask) -> Loader? {
            guard let url = dataTask.originalRequest?.url else { return nil }
            return StoriesCollectionCellLoader.manager.storage[url]
        }

        func getLoader(with url: URL, task: Task) -> Loader {
            let loader = StoriesCollectionCellLoader.manager.getLoader(with: url)
            loader.operative.update(task)
            return loader
        }
    }

    class LoaderManager {

        let session: URLSession
        let storage = HashStorage<URL, Loader>()
        var disk = Disk()

        init(configuration: URLSessionConfiguration = .default) {
            self.session = URLSession(configuration: .default, delegate: StoriesCollectionCellLoader.session, delegateQueue: nil)
        }

        func getLoader(with url: URL) -> Loader {
            if let loader = storage[url] {
                return loader
            }

            let loader = Loader(session.dataTask(with: url), reqUrl: url, delegate: self)
            storage[url] = loader
            return loader
        }

        func getLoader(with url: URL, task: Task) -> Loader {
            let loader = getLoader(with: url)
            loader.operative.update(task)
            return loader
        }

        func remove(_ loader: Loader) {
            guard let url = storage.getKey(loader) else {
                return
            }
            storage[url] = nil
        }
    }
}
