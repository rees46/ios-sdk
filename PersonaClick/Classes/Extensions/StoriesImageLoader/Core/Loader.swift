import Foundation
import UIKit

public struct Loader {

    unowned let delegate: StoriesCollectionCellLoader.LoaderManager
    let task: URLSessionDataTask
    let operative = Operative()
    let baseReqUrl: URL

    init(_ task: URLSessionDataTask, reqUrl: URL, delegate: StoriesCollectionCellLoader.LoaderManager) {
        self.task = task
        self.baseReqUrl = reqUrl
        self.delegate = delegate
    }

    public var state: URLSessionTask.State {
        return task.state
    }

    public func resume() {
        task.resume()
    }

    public func cancel() {
        task.cancel()
        let reason = "SDK Loader cancel to request: \(baseReqUrl)"
        onFailure(with: NSError(domain: "StoriesCollectionCellLoader", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey: reason]))
    }

    func complete(with error: Error?) {
        if let error = error {
            onFailure(with: error)
            return
        }

        if let image = UIImage.process(data: operative.receiveData) {
            onSuccess(with: image)
            delegate.disk.set(operative.receiveData, forKey: baseReqUrl)
            return
        }

        if let statusCode = (task.response as? HTTPURLResponse)?.statusCode, statusCode >= 200, statusCode < 400 {
            let reason = "SDK Disconnect on downloading caused by HTTPStatusCode: \(statusCode)"
            onFailure(with: NSError(domain: "StoriesCollectionCellLoader", code: statusCode, userInfo: [NSLocalizedFailureReasonErrorKey: reason]))
            return
        }

        failOnConvertToImage()
    }

    private func failOnConvertToImage() {
        onFailure(with: NSError(domain: "StoriesCollectionCellLoader", code: -999, userInfo: [NSLocalizedFailureReasonErrorKey: "SDK Failure when convert image"]))
    }

    private func onSuccess(with image: UIImage) {
        operative.tasks.forEach { task in
            task.onCompletion(image, nil, .network)
        }
        operative.tasks = []
        delegate.remove(self)
    }

    private func onFailure(with error: Error) {
        operative.tasks.forEach { task in
            task.onCompletion(nil, error, .error)
        }
        operative.tasks = []
        delegate.remove(self)
    }
}


extension Loader: Equatable {}

public func == (lhs: Loader, rhs: Loader) -> Bool {
    return lhs.task == rhs.task
}
