import UIKit

protocol FiltersRoundedButtonDelegate: AnyObject {
    func filtersRoundedButton(didTap button: FiltersRoundedButton)
}

class FiltersRoundedButton: UIButton {
    
    var highlightedColor = #colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1) {
        didSet {
            guard oldValue != highlightedColor else {
                return
            }
            setColor()
        }
    }
    
    override var isSelected: Bool {
        didSet {
            guard oldValue != isSelected else {
                return
            }
            setColor()
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else {
                return
            }
            setColor()
        }
    }
    
    weak var delegate: FiltersRoundedButtonDelegate?
    
    private let label = UILabel()
    
    init(hasBlurEffect: Bool = false) {
        super.init(frame: CGRect.zero)
        setupButton()
        
        if hasBlurEffect {
            setupBlurEffect()
        } else {
            setupWhiteBackground()
        }
        
        setupLabel()
        setColor()
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTitle(_ title: String) {        
        label.text = title
    }
    
    func setFont(_ font: UIFont) {
        label.font = font
    }
    
    private func setupButton() {
        layer.cornerRadius = 12
        layer.borderWidth = 2
        clipsToBounds = true
    }
    
    private func setupBlurEffect() {
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.isUserInteractionEnabled = false
        self.addSubview(blurEffectView)
        blurEffectView.constrainEdges(to: self)
    }
    
    private func setupWhiteBackground() {
        let whiteBackground = UIView()
        whiteBackground.isUserInteractionEnabled = false
        whiteBackground.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        self.addSubview(whiteBackground)
        whiteBackground.constrainEdges(to: self)
    }
    
    private func setupLabel() {
        label.numberOfLines = 0
        label.font = UIFont.boldSystemFont(ofSize: 16)
        addSubview(label)
        label.constrainEdges(to: self, insets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15))
    }
    
    private func setColor() {
        let shouldHaveColor = !isSelected && isHighlighted || isSelected && !isHighlighted
        let color = shouldHaveColor ? highlightedColor : .sdkDefaultBordoColor
        //let hColor = UIColor.hexStringFromColor(color: .brown)
        label.textColor = .systemPink
        layer.borderColor = color.cgColor
    }

    @objc
    func tapped() {
        isSelected = !isSelected
        delegate?.filtersRoundedButton(didTap: self)
    }
}
