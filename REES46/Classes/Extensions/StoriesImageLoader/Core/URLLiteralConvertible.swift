import Foundation

public protocol URLLiteralConvertible {
    var storiesCollectionCellLoaderURL: URL? { get }
}

extension URL: URLLiteralConvertible {
    public var storiesCollectionCellLoaderURL: URL? {
        return self
    }
}

extension URLComponents: URLLiteralConvertible {
    public var storiesCollectionCellLoaderURL: URL? {
        return url
    }
}

extension String: URLLiteralConvertible {
    public var storiesCollectionCellLoaderURL: URL? {
        if let string = addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: string)
        }
        return URL(string: self)
    }
}
