import Foundation

extension Optional where Wrapped == PersonalizationSDK {
    func checkInitialization<T>(
        completion: @escaping (Result<T, SdkError>) -> Void
    ) -> PersonalizationSDK? {
        guard let sdk = self else {
            completion(.failure(.custom(error: "SDK is not initialized")))
            return nil
        }
        return sdk
    }
}
