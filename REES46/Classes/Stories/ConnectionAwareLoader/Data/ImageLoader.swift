import Foundation
import UIKit

class ImageLoader: ImageLoading {
    
    func loadImage(from url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data, let image = UIImage(data: data) else {
                    let error = NSError(domain: "com.rees46", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve data."])
                    completion(.failure(error))
                    return
                }

                completion(.success(image))
            }
        }
        task.resume()
    }
}
