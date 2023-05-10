import Foundation

public protocol URLLiteralConvertible {
    var storiesImageLoaderURL: URL? { get }
}

extension URL: URLLiteralConvertible {
    public var storiesImageLoaderURL: URL? {
        return self
    }
}

extension URLComponents: URLLiteralConvertible {
    public var storiesImageLoaderURL: URL? {
        return url
    }
}

extension String: URLLiteralConvertible {
    public var storiesImageLoaderURL: URL? {
        if let string = addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: string)
        }
        return URL(string: self)
    }
}
