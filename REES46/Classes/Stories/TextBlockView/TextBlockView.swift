import UIKit
import Foundation

class TextBlockView: UIView {
    let yOffset: CGFloat
    
    private let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(with textBlockConfiguration: TextBlockConfiguration) {
        self.yOffset = textBlockConfiguration.appearanceConfiguration.yOffset
        super.init(frame: .zero)
        configureLabel(with: textBlockConfiguration)
        setupView(hasBackground: textBlockConfiguration.appearanceConfiguration.backgroundColor != .clear)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView(hasBackground: Bool) {
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: hasBackground ? 16 : 0),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: hasBackground ? -16 : 0)
        ])
    }
    
    private func configureLabel(with config: TextBlockConfiguration) {
        label.font = config.fontConfiguration.font
        label.textColor = config.appearanceConfiguration.textColor
        self.layer.cornerRadius = config.appearanceConfiguration.cornerRadius
        self.clipsToBounds = config.appearanceConfiguration.clipsToBounds
        self.backgroundColor = config.appearanceConfiguration.backgroundColor
        label.attributedText = config.textConfiguration.text
        label.textAlignment = config.textConfiguration.textAlignment
    }
    
    override var intrinsicContentSize: CGSize {
        let labelSize = label.intrinsicContentSize
        return CGSize(width: labelSize.width + 32, height: labelSize.height + 16)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
