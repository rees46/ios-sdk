import UIKit

class ImagesCollectionViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var oldPriceLabel: UILabel!
    @IBOutlet var oldPriceView: UIView!
    @IBOutlet var priceLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        oldPriceView.isHidden = true
        nameLabel.textColor = .black
        priceLabel.textColor = .black
        layer.cornerRadius = 8.0
    }

    func configure(product: Product) {
        if let oldPrice = product.oldPrice, !oldPrice.isEmpty {
            oldPriceView.isHidden = false
            oldPriceLabel.attributedText = strikeThrough(str: oldPrice)
        } else {
            oldPriceView.isHidden = true
        }
        priceLabel.text = product.price
        nameLabel.text = product.name
        setImage(imagePath: product.imageUrl)
    }

    private func strikeThrough(str: String) -> NSAttributedString {
        let attributeString = NSMutableAttributedString(string: str)
        attributeString.addAttribute(NSAttributedString.Key.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSMakeRange(0, attributeString.length))
        return attributeString
    }

    private func setImage(imagePath: String) {
        guard let url = URL(string: imagePath) else {
            return
        }

        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
            if error == nil {
                guard let unwrappedData = data, let image = UIImage(data: unwrappedData) else { return }
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }
        })
        task.resume()
    }
}
