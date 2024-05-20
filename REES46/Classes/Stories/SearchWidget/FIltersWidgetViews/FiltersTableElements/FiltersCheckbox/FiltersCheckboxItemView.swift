import UIKit

public class FiltersCheckboxItemView<T: FiltersCheckboxItem>: UIView {
    
    public private(set) var style: FiltersCheckboxTreeStyle<T>
    
    public private(set) var groupArrowButton: UIButton?
    public private(set) var selectionImageView: UIImageView?
    
    public internal(set) var tapAction: (() -> ())?
    public internal(set) var collapseAction: (() -> ())?
    
    public required init(style: FiltersCheckboxTreeStyle<T>) {
        self.style = style
        super.init(frame: .zero)
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(itemTapped(gestureRecognizer:)))
        addGestureRecognizer(gestureRecognizer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc public func itemTapped(gestureRecognizer: UITapGestureRecognizer) {
        tapAction?()
    }
    
    @objc public func collapseIconTapped(gestureRecognizer: UITapGestureRecognizer) {
        collapseAction?()
    }
    
    public func transformGroupArrow(isCollapsed: Bool) {
        groupArrowButton?.transform = isCollapsed ? .identity : .identity.rotated(by: .pi/2)
    }
    
    public func updateSelectionImage(item: FiltersCheckboxItem) {
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        
        let checkboxOnImg = UIImage(named: "icCheckboxFilledOn", in: frameworkBundle, compatibleWith: nil)
        let checkboxOffImg = UIImage(named: "icCheckboxFilledOff", in: frameworkBundle, compatibleWith: nil)
        let checkboxMixedImg = UIImage(named: "icCheckboxFilledMixed", in: frameworkBundle, compatibleWith: nil)
        //let groupArrowImg = UIImage(named: "angleDownBlack", in: frameworkBundle, compatibleWith: nil)
        
        switch item.selectionState {
        case .currentFilterOn:
            selectionImageView?.image = checkboxOnImg //style.images.checkboxOn
        case .currentFilterOff:
            selectionImageView?.image = checkboxOffImg //style.images.checkboxOff
        case .currentFilterMixed:
            selectionImageView?.image = checkboxMixedImg //style.images.checkboxMixed
        }
        
        if !item.isEnabled {
            selectionImageView?.image = selectionImageView?.image?.withRenderingMode(.alwaysTemplate)
            selectionImageView?.tintColor = style.itemViewStyle.disabledStateColor
        }
    }
    
    public func setupView(item: T, level: Int) {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.spacing = style.itemViewStyle.elementsSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        heightAnchor.constraint(greaterThanOrEqualToConstant: style.itemViewStyle.minHeight).isActive = true
        
        for _ in 0..<level {
            stackView.addArrangedSubview(levelBoxView())
        }
        
        if style.isCollapseAvailable {
            stackView.addArrangedSubview(groupArrowView(item: item))
        }
        
        stackView.addArrangedSubview(selectionImageView(item: item))
        
        stackView.addArrangedSubview(titleView(item: item))
        
        if style.isCollapseAvailable {
            stackView.addArrangedSubview(groupArrowView(item: item))
        }
    }
    
    public func levelBoxView() -> UIView {
        let emptyView = UIView()
        NSLayoutConstraint.activate([
            emptyView.widthAnchor.constraint(equalToConstant: style.itemViewStyle.levelBoxSize.width),
            emptyView.heightAnchor.constraint(equalToConstant: style.itemViewStyle.levelBoxSize.height)
        ])
        return emptyView
    }
    
    public func groupArrowView(item: T) -> UIView {
        if item.type == .groupCheckbox {
            let button = UIButton()
            button.setBackgroundImage(style.images.groupArrow, for: .normal)
            button.addTarget(self, action: #selector(collapseIconTapped(gestureRecognizer:)), for: .touchUpInside)
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: style.itemViewStyle.levelBoxSize.width),
                button.heightAnchor.constraint(equalToConstant: style.itemViewStyle.levelBoxSize.height)
            ])
            
            groupArrowButton = button
            transformGroupArrow(isCollapsed: item.isGroupCollapsed)
            
            return button
        } else {
            return levelBoxView()
        }
    }
    
    public func selectionImageView(item: T) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: style.itemViewStyle.levelBoxSize.width),
            imageView.heightAnchor.constraint(equalToConstant: style.itemViewStyle.levelBoxSize.height)
        ])
        
        selectionImageView = imageView
        updateSelectionImage(item: item)
        
        return imageView
    }
    
    public func titleView(item: T) -> UIView {
        let titleStackView = UIStackView()
        titleStackView.axis = .vertical
        
        let titleLabel = UILabel(frame: CGRect.zero)
        titleLabel.font = style.itemViewStyle.titleFont
        titleLabel.textColor = item.isEnabled ? style.itemViewStyle.titleColor : style.itemViewStyle.disabledStateColor
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 0
        titleLabel.text = item.title
        
        titleStackView.addArrangedSubview(titleLabel)
        
        if let subtitle = item.subtitle {
            let subtitleLabel = UILabel(frame: CGRect.zero)
            subtitleLabel.font = style.itemViewStyle.subtitleFont
            subtitleLabel.textColor = item.isEnabled ? style.itemViewStyle.subtitleColor : style.itemViewStyle.disabledStateColor
            subtitleLabel.textAlignment = .left
            subtitleLabel.numberOfLines = 0
            subtitleLabel.text = subtitle
            
            titleStackView.addArrangedSubview(subtitleLabel)
        }
        
        return titleStackView
    }
}
