import UIKit

public final class StoriesCacheManager {

    public class var cacheDirectoryPath: String {
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as NSString

        return path.appendingPathComponent("rstories-cache")
    }

    public enum Storage {
        case memory
        case disk(path: String)
        case all(diskPath: String)
    }

    private let storage: Storage
    private let cache = NSCache<NSString, UIImage>()

    public init(storage: Storage = .all(diskPath: cacheDirectoryPath)) throws {
        self.storage = storage

        try setupStorage(storage)
    }

    
    internal func image(forKey key: String, storage: Storage? = nil) throws -> UIImage? {
        let storage = storage ?? self.storage

        try setupStorage(storage)

        switch storage {
        case .memory:
            return cache.object(forKey: key as NSString)

        case .disk(let path):
            return UIImage(contentsOfFile: imagePath(base: path, key: key))

        case .all(let diskPath):
            var image = cache.object(forKey: key as NSString)

            if image == nil {
                image = UIImage(contentsOfFile: imagePath(base: diskPath, key: key))
            }

            return image
        }
    }
    
    internal func saveImage(_ image: UIImage, forKey key: String, storage: Storage? = nil) throws {
        let storage = storage ?? self.storage

        try setupStorage(storage)

        DispatchQueue.global(qos: .background).async {
            switch storage {
            case .memory:
                self.cache.setObject(image, forKey: key as NSString)

            case .disk(let path):
                try? self.saveImage(image, byPath: self.imagePath(base: path, key: key))

            case .all(let diskPath):
                self.cache.setObject(image, forKey: key as NSString)

                try? self.saveImage(image, byPath: self.imagePath(base: diskPath, key: key))
            }
        }
    }
    
    internal func clear(_ completion: ((_ error: Error?) -> Void)? = nil) {
        cache.removeAllObjects()

        DispatchQueue.global(qos: .background).async {
            var error: Error?

            switch self.storage {
            case .memory:
                break

            case .disk(let path), .all(let path):
                let fileManager = FileManager.default

                do {
                    let files = try fileManager.contentsOfDirectory(atPath: path)
                    for file in files {
                        try fileManager.removeItem(atPath: self.imagePath(base: path, key: file))
                    }
                } catch let err {
                    error = err
                }
            }

            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }

    private func setupStorage(_ storage: Storage) throws {
        switch storage {
        case .memory:
            break

        case .disk(let path), .all(let path):
            var isDir: ObjCBool = false
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: path, isDirectory: &isDir) {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            }
        }
    }

    private func saveImage(_ image: UIImage, byPath path: String) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: nil, attributes: nil)
        }

        try image.pngData()?.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func imagePath(base: String, key: String) -> String {
        return (base as NSString).appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
    }
}
