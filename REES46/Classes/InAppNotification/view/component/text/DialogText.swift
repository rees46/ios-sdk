import UIKit
class DialogText: UILabel {
    
    init(text: String, fontSize: CGFloat, isBold: Bool = false) {
        super.init(frame: .zero)
        setupUI(text: text, fontSize: fontSize, isBold: isBold)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI(text: String, fontSize: CGFloat, isBold: Bool) {
        self.text = text
        font = isBold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        numberOfLines = 0
        textColor = AppColors.Text.message
    }
}
