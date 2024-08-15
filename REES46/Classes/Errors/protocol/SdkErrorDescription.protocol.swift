import Foundation

public protocol SdkErrorDescription: Error {
    var description: String { get }
}
