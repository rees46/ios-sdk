import Foundation
import UIKit

protocol ImageLoadingProtocol {
    func loadImage(from url: URL, completion: @escaping (Result<UIImage, Error>) -> Void)
}

class DefaultImageLoader: ImageLoadingProtocol {
    
    func loadImage(from url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(ImageLoaderError.networkError(error)))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    completion(.failure(ImageLoaderError.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    completion(.failure(ImageLoaderError.dataConversionError))
                    return
                }
                
                completion(.success(image))
            }
        }
        task.resume()
    }
}
