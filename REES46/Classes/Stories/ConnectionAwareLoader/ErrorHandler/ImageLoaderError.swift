import Foundation

enum ImageLoaderError: Error {
    case networkError(Error)
    case serverError(Int)
    case dataConversionError
    case unknownError
    
    var localizedDescription: String {
        switch self {
        case .networkError(let error):
            return error.localizedDescription
        case .serverError(let statusCode):
            return "Server returned status code \(statusCode)"
        case .dataConversionError:
            return "Failed to convert data to image"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
