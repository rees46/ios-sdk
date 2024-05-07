import UIKit

class SliderCell: UICollectionViewCell {
    
    @IBOutlet weak var productImages: UIImageView!
    
    override func draw(_ rect: CGRect) {
        layer.cornerRadius = 5
        clipsToBounds = true
    }
    
    func updateCell(with image: String) {
        
        if let url = URL(string: image) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                guard let imageData = data else {
                    return
                }

                DispatchQueue.main.async {
                    UIView.animate(withDuration: 1.7, delay: 0.0,
                        usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0,
                        options: .allowAnimatedContent, animations: {
                        self.productImages.image = UIImage(data: imageData)
                    }) { (isFinished) in
                    }
                    self.productImages.image = UIImage(data: imageData)
                }
            }.resume()
      }
    }
    
}
