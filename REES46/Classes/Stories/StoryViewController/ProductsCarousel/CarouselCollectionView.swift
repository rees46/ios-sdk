import UIKit
import WebKit

class CarouselCollectionView: UICollectionView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var cells = [StoriesProduct]()
    var hideButton = UIButton()
    var hideLabel: String?
    
    public weak var carouselProductsDelegate: CarouselCollectionViewCellDelegate?
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        super.init(frame: .zero, collectionViewLayout: layout)
        
        backgroundColor = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 255/255)
        delegate = self
        dataSource = self
        register(CarouselCollectionViewCell.self, forCellWithReuseIdentifier: CarouselCollectionViewCell.reuseCarouselId)
        
        translatesAutoresizingMaskIntoConstraints = false
        layout.minimumLineSpacing = CarouselProductsConstants.productCarouselMinimumLineSpacing
        
        if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
            contentInset = UIEdgeInsets(top: 0, left: CarouselProductsConstants.cLeftDistanceToView, bottom: 70, right: CarouselProductsConstants.cRightDistanceToView)
        } else {
            contentInset = UIEdgeInsets(top: 0, left: CarouselProductsConstants.cLeftDistanceToView, bottom: 60, right: CarouselProductsConstants.cRightDistanceToView)
        }
        
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.backgroundColor = .clear
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        if SdkGlobalHelper.DeviceType.IS_IPHONE_XS {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 9),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 9),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14 {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 9),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 9),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 9),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: -6),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: -19),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_8_PLUS {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: -19),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 9),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        }
        
        hideButton = UIButton(frame: CGRect(x: 0, y: 0, width: 85, height: 40))
        hideButton.translatesAutoresizingMaskIntoConstraints = false
        hideButton.setTitle(hideLabel ?? SdkConfiguration.stories.defaultHideProductsButtonText, for: .normal)
        if hideLabel == nil || hideLabel == "" {
            hideButton.setTitle(SdkConfiguration.stories.defaultHideProductsButtonText, for: .normal)
        }
        
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            hideButton.titleLabel?.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 14)
        } else {
            hideButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        }
        hideButton.backgroundColor = .clear
        hideButton.setTitleColor(UIColor.black, for: .normal)
        hideButton.addTarget(self, action: #selector(self.closeButtonTapped), for: .touchUpInside)
        
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        let image = UIImage(named: "angleDownBlack", in: frameworkBundle, compatibleWith: nil)
        
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        hideButton.addSubview(imageView)

        let length = CGFloat(21)
        hideButton.titleEdgeInsets.right += length

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: hideButton.titleLabel!.trailingAnchor, constant: 6),
            imageView.centerYAnchor.constraint(equalTo: hideButton.titleLabel!.centerYAnchor, constant: 1),
            imageView.widthAnchor.constraint(equalToConstant: length),
            imageView.heightAnchor.constraint(equalToConstant: length)
        ])
        
        stackView.addArrangedSubview(hideButton)
        addSubview(stackView)
    }
    
    @objc
    func closeButtonTapped(sender: UIButton) {
        carouselProductsDelegate?.closeProductsCarousel()
    }
    
    func set(cells: [StoriesProduct]) {
        self.cells = cells
        redrawSubviews()
        
        self.hideButton.setTitle(hideLabel ?? SdkConfiguration.stories.defaultHideProductsButtonText, for: .normal)
        if hideLabel == nil || hideLabel == "" {
            hideButton.setTitle(SdkConfiguration.stories.defaultHideProductsButtonText, for: .normal)
        }
    }
    
    func redrawSubviews() {
        if cells.count == 1 {
            contentInset = UIEdgeInsets(top: 0, left: UIScreen.main.bounds.size.width/4 - 10, bottom: 70, right: 0)
        } else {
            if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
                contentInset = UIEdgeInsets(top: 0, left: CarouselProductsConstants.cLeftDistanceToView, bottom: 70, right: CarouselProductsConstants.cRightDistanceToView)
            } else {
                contentInset = UIEdgeInsets(top: 0, left: CarouselProductsConstants.cLeftDistanceToView, bottom: 60, right: CarouselProductsConstants.cRightDistanceToView)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cells.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = dequeueReusableCell(withReuseIdentifier: CarouselCollectionViewCell.reuseCarouselId, for: indexPath) as! CarouselCollectionViewCell
        
        let url = URL(string: cells[indexPath.row].picture)
        if url != nil {
            cell.carouselMainImageView.load.request(with: url!)
        }
        cell.carouselProductNameLabel.text = cells[indexPath.row].name
        
        let mainProductText = cells[indexPath.row].oldprice_formatted
        let textRange = NSMakeRange(0, mainProductText.count)
        let attributedText = NSMutableAttributedString(string: mainProductText)
        attributedText.addAttribute(NSAttributedString.Key.strikethroughStyle , value: NSUnderlineStyle.single.rawValue, range: textRange)
        cell.carouselOldCostLabel.attributedText = attributedText
        
        if (cells[indexPath.row].discount_formatted == "0%" || cells[indexPath.row].discount_formatted == nil) {
            cell.carouselDiscountLabel.isHidden = true
        } else {
            let discountPercent = cells[indexPath.row].discount_formatted ?? "10%"
            let discountPercentFinal = " -" + discountPercent + " "
            cell.carouselDiscountLabel.text = discountPercentFinal
            cell.carouselDiscountLabel.isHidden = false
        }
        
        cell.carouselNowCostLabel.text = cells[indexPath.row].price_formatted
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedCarouselProduct = cells[indexPath.row]
        carouselProductsDelegate?.sendStructSelectedCarouselProduct(product: selectedCarouselProduct)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
            return CGSize(width: CarouselProductsConstants.productCarouselItemSlimWidth, height: frame.height * 0.73)
        } else {
            return CGSize(width: CarouselProductsConstants.productCarouselItemWidth, height: frame.height * 0.73)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UIButton {
    func addRightIcon(image: UIImage) {
        
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(imageView)

        let length = CGFloat(21)
        titleEdgeInsets.right += length

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: self.titleLabel!.trailingAnchor, constant: 6),
            imageView.centerYAnchor.constraint(equalTo: self.titleLabel!.centerYAnchor, constant: 1),
            imageView.widthAnchor.constraint(equalToConstant: length),
            imageView.heightAnchor.constraint(equalToConstant: length)
        ])
    }
}
