import UIKit

class FiltersMenuCollectionViewCell: UICollectionViewCell {
    
    let button = FiltersRoundedButton()
    weak var delegate: FiltersMenuCollectionDelegate?
    
    var didTapCell: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(button)
        button.constrainCenterX(to: contentView)
        button.constrainCenterY(to: contentView)
        button.delegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(title: String, font: UIFont, didTapCell: @escaping () -> Void) {
        self.didTapCell = didTapCell
        button.setFont(font)
        button.setTitle(title)
    }
}

extension FiltersMenuCollectionViewCell: FiltersRoundedButtonDelegate {
    func filtersRoundedButton(didTap button: FiltersRoundedButton) {
        didTapCell?()
    }
}
