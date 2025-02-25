import Foundation

public protocol URLHandler {
    func open(url: URL, completion: @escaping (Result<Void, Error>) -> Void)
}
