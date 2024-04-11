import UIKit

protocol FiltersRoundedButtonStackDelegate: AnyObject {
    func filtersMenuStack(didSelectAtIndex index: Int)
}

class FiltersRoundedButtonMenuStack: UIScrollView {
    
    weak var filtersRoundedButtonStackDelegate: FiltersRoundedButtonStackDelegate?
    
    var interitemSpacing: CGFloat = 10 {
        didSet {
            stackView.spacing = interitemSpacing
        }
    }
    
    private let stackView = UIStackView()
    
    init() {
        super.init(frame: CGRect.zero)
        stackView.backgroundColor = .green
        
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        
        self.addSubview(stackView)
        stackView.axis = .vertical
        stackView.constrainEdges(to: self)
        stackView.spacing = interitemSpacing
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(fMenuItems: [FiltersRoundedMenuCollection]) {
        for arrangeSubview in stackView.arrangedSubviews {
            arrangeSubview.removeFromSuperview()
        }
        
        for (index, menuItem) in fMenuItems.enumerated() {
            let button = FiltersRoundedButton(hasBlurEffect: true)
            button.tag = index
            button.setTitle(menuItem.name)
            button.delegate = self
            stackView.addArrangedSubview(button)
        }
    }    
}

extension FiltersRoundedButtonMenuStack: FiltersRoundedButtonDelegate {
    func filtersRoundedButton(didTap button: FiltersRoundedButton) {
        filtersRoundedButtonStackDelegate?.filtersMenuStack(didSelectAtIndex: button.tag)
    }
}
