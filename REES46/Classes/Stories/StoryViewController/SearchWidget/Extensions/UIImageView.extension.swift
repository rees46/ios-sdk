import UIKit

extension UIImageView {
    func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            SdkLogger.area(.ui, .debug, "an image has no valid URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                SdkLogger.area(.ui, .debug, "an image was not loaded: \(SdkLogger.errorKind(error))")
                return
            }
            
            let image = UIImage(data: data)
            
            DispatchQueue.main.async {
                self?.image = image
            }
        }
        task.resume()
    }
}
