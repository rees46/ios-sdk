import UIKit

public final class StoriesImageLoader {

    public typealias Result = (_ result: Swift.Result<UIImage, StoriesImageLoader.Error>) -> Void

    public enum Error: Swift.Error {
        case invalidUrl
        case loadingFailed(Swift.Error)
        case corruptedImage
    }

    public var enableLog = false

    public static let shared = StoriesImageLoader()

    private let session: URLSession
    private var cache: StoriesCacheManager?

    private init() {
        session = URLSession(configuration: URLSessionConfiguration.default,
                             delegate: nil,
                             delegateQueue: OperationQueue.main)

        do {
            setupCache(try StoriesCacheManager())
        } catch {
            log(message: error.localizedDescription)
        }
    }
    

    @discardableResult
    public func setupCache(_ cache: StoriesCacheManager) -> Self {
        self.cache?.clear()

        self.cache = cache

        return self
    }

    
    @discardableResult
    public func load(_ url: URL?,
                     placeholder: UIImage? = nil,
                     into imageView: UIImageView,
                     apply transformations: [Transformation] = [],
                     cacheStrategy: CacheStrategy = .tranformed(key: nil),
                     completion: Result? = nil) -> URLSessionDataTask? {
        imageView.image = placeholder

        guard let url = url else {
            completion?(.failure(.invalidUrl))

            return nil
        }

        return load(URLRequest(url: url),
                    into: imageView,
                    apply: transformations,
                    cacheStrategy: cacheStrategy,
                    completion: completion)
    }

    
    @discardableResult
    public func load(_ request: URLRequest,
                     placeholder: UIImage? = nil,
                     into imageView: UIImageView,
                     apply transformations: [Transformation] = [],
                     cacheStrategy: CacheStrategy = .tranformed(key: nil),
                     completion: Result? = nil) -> URLSessionDataTask? {
        imageView.image = placeholder

        return load(request, apply: transformations, cacheStrategy: cacheStrategy) { result in
            switch result {
            case .success(let image):
                if let completion = completion {
                    completion(.success(image))
                } else {
                    imageView.image = image
                    imageView.setNeedsDisplay()
                }

            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    
    @discardableResult
    public func load(_ url: URL?,
                     apply transformations: [Transformation] = [],
                     cacheStrategy: CacheStrategy = .tranformed(key: nil),
                     completion: Result? = nil) -> URLSessionDataTask? {
        guard let url = url else {
            completion?(.failure(.invalidUrl))

            return nil
        }

        return load(URLRequest(url: url),
                    apply: transformations,
                    cacheStrategy: cacheStrategy,
                    completion: completion)
    }

    
    @discardableResult
    public func load(_ request: URLRequest,
                     apply transformations: [Transformation] = [],
                     cacheStrategy: CacheStrategy = .tranformed(key: nil),
                     completion: Result? = nil) -> URLSessionDataTask? {
        guard let url = request.url?.absoluteString, !url.isEmpty else {
            completion?(.failure(.invalidUrl))

            return nil
        }

        log(message: "loading image from url => \(url)")

        if let image = try? image(for: cacheStrategy, url: url) {
            log(message: "got an image from the cache")

            completion?(.success(image))

            return nil
        }

        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
            if let error = error {
                completion?(.failure(.loadingFailed(error)))

                self?.log(message: "error image loading \(error)")
            } else {
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.global(qos: .userInitiated).async {
                        var result = image
                        for transformation in transformations {
                            result = transformation.transform(result)
                        }

                        try? self?.saveImage(original: image, transformed: result, strategy: cacheStrategy, url: url)

                        DispatchQueue.main.async {
                            completion?(.success(result))
                            self?.log(message: "loaded image from url => \(url)")
                        }
                    }
                } else {
                    completion?(.failure(.corruptedImage))
                }
            }
        }

        task.resume()

        return task
    }
    
    public func cancelOperation(url: URL?) {
        allTasks(of: session) { tasks in
            for task in tasks where task.currentRequest?.url == url {
                task.cancel()
            }
        }
    }

    public func cancelAllOperations() {
        allTasks(of: session) { tasks in
            for task in tasks {
                task.cancel()
            }
        }
    }

    public func clearCache(_ completion: ((_ error: Swift.Error?) -> Void)? = nil) {
        cache?.clear(completion)
    }

    private func image(for strategy: CacheStrategy, url: String) throws -> UIImage? {
        var image: UIImage?

        switch strategy {
        case .original(let key), .tranformed(let key):
            image = try cache?.image(forKey: key ?? url)

        case .both(let original, let tranformed):
            image = try cache?.image(forKey: original ?? url)

            if image == nil {
                image = try cache?.image(forKey: tranformed ?? url)
            }
        }

        return image
    }

    private func saveImage(original: UIImage, transformed: UIImage, strategy: CacheStrategy, url: String) throws {
        switch strategy {
        case .original(let key):
            try cache?.saveImage(original, forKey: key ?? url)

        case .tranformed(let key):
            try cache?.saveImage(transformed, forKey: key ?? "\(url)+transformed")

        case .both(let originalKey, let tranformedKey):
            try cache?.saveImage(original, forKey: originalKey ?? url)

            try cache?.saveImage(transformed, forKey: tranformedKey ?? "\(url)+transformed")
        }
    }

    private func allTasks(of session: URLSession, completionHandler: @escaping ([URLSessionTask]) -> Void) {
        session.getTasksWithCompletionHandler { (data, upload, download) in
            let tasks = data as [URLSessionTask] + upload as [URLSessionTask] + download as [URLSessionTask]

            completionHandler(tasks)
        }
    }

    private func log(message: String) {
        if enableLog {
            print("StoriesImageLoader: \(message)")
        }
    }
}
