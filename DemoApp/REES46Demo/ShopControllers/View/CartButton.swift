import UIKit

class CartButton: UIBarButtonItem {
    public func setBadge(with value: Int) {
            self.badgeValue = value
        }

        private var badgeValue: Int? {
            didSet {
                if let value = badgeValue,
                    value > 0 {
                    lblBadge.isHidden = false
                    lblBadge.text = "\(value)"
                } else {
                    lblBadge.isHidden = true
                }
            }
        }

        var tapAction: (() -> Void)?

        private let filterBtn = UIButton()
        private let lblBadge = UILabel()

        override init() {
            super.init()
            setup()
        }

        init(image: UIImage?) {
            super.init()
            setup(image: image)
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            setup()
        }

        private func setup(image: UIImage? = nil) {

            filterBtn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            filterBtn.adjustsImageWhenHighlighted = false
            filterBtn.setImage(image, for: .normal)
            filterBtn.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)

            lblBadge.frame = CGRect(x: 20, y: 0, width: 15, height: 15)
            lblBadge.backgroundColor = .systemRed
            lblBadge.clipsToBounds = true
            lblBadge.layer.cornerRadius = 7
            lblBadge.textColor = UIColor.white
            lblBadge.font = UIFont(name: "Gill Sans", size: 10)
            lblBadge.textAlignment = .center
            lblBadge.isHidden = true
            lblBadge.minimumScaleFactor = 0.1
            lblBadge.adjustsFontSizeToFitWidth = true
            filterBtn.addSubview(lblBadge)
            customView = filterBtn
        }

        @objc
    func buttonPressed() {
            if let action = tapAction {
                action()
            }
        }
}
