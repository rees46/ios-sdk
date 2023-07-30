import UIKit
import WebKit

class CarouselCollectionView: UICollectionView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var cells = [StoriesProduct]()
    
    public weak var carouselProductsDelegate: CarouselCollectionViewCellDelegate?
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        super.init(frame: .zero, collectionViewLayout: layout)
        
        backgroundColor = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 255/255)
        //UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 171/255)
        delegate = self
        dataSource = self
        register(CarouselCollectionViewCell.self, forCellWithReuseIdentifier: CarouselCollectionViewCell.reuseId)
        
        translatesAutoresizingMaskIntoConstraints = false
        layout.minimumLineSpacing = CarouselConstants.carouselMinimumLineSpacing
        
        if GlobalHelper.DeviceType.IS_IPHONE_8 {
            contentInset = UIEdgeInsets(top: 0, left: CarouselConstants.leftDistanceToView, bottom: 70, right: CarouselConstants.rightDistanceToView)
        } else {
            contentInset = UIEdgeInsets(top: 0, left: CarouselConstants.leftDistanceToView, bottom: 60, right: CarouselConstants.rightDistanceToView)
        }
        
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.backgroundColor = .clear
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        if GlobalHelper.DeviceType.IS_IPHONE_XS {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                //stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 15),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if GlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 14),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if GlobalHelper.DeviceType.IS_IPHONE_14 {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 14),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if GlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 14),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if GlobalHelper.DeviceType.IS_IPHONE_14_PRO {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 14),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if GlobalHelper.DeviceType.IS_IPHONE_5 {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: -6),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if GlobalHelper.DeviceType.IS_IPHONE_8 {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 58),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -58),
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: -19),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        } else if GlobalHelper.DeviceType.IS_IPHONE_8P {
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
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 14),
                stackView.heightAnchor.constraint(equalToConstant: 36)
            ])
        }
        
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 85, height: 40))
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.setTitle("Скрыть товары", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        button.backgroundColor = .clear //.white
        button.setTitleColor(UIColor.black, for: .normal)
        //button.layer.cornerRadius = button.frame.size.height / 2
        //button.layer.borderWidth = 1.2
        //button.layer.masksToBounds = true
        //button.layer.borderColor = UIColor.black.cgColor
        
        button.addTarget(self, action: #selector(self.buttonTapped), for: .touchUpInside)
        
        var mainBundle = Bundle(for: classForCoder)
    #if SWIFT_PACKAGE
        mainBundle = Bundle.module
    #endif
        let image = UIImage(named: "angleDownBlack", in: mainBundle, compatibleWith: nil)
        
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(imageView)

        let length = CGFloat(21)
        button.titleEdgeInsets.right += length

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: button.titleLabel!.trailingAnchor, constant: 6),
            imageView.centerYAnchor.constraint(equalTo: button.titleLabel!.centerYAnchor, constant: 1),
            imageView.widthAnchor.constraint(equalToConstant: length),
            imageView.heightAnchor.constraint(equalToConstant: length)
        ])
        
        stackView.addArrangedSubview(button)
        addSubview(stackView)
    }
    
    @objc func buttonTapped(sender : UIButton) {
        carouselProductsDelegate?.closeProductsCarousel()
    }
    
    func set(cells: [StoriesProduct]) {
        self.cells = cells
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cells.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = dequeueReusableCell(withReuseIdentifier: CarouselCollectionViewCell.reuseId, for: indexPath) as! CarouselCollectionViewCell
        
        let url = URL(string: cells[indexPath.row].picture)!
        
        cell.mainImageView.load.request(with: url)
        cell.nameLabel.text = cells[indexPath.row].name
        
        let mainProductText = cells[indexPath.row].oldprice_formatted
        let textRange = NSMakeRange(0, mainProductText.count)
        let attributedText = NSMutableAttributedString(string: mainProductText)
        attributedText.addAttribute(NSAttributedString.Key.strikethroughStyle , value: NSUnderlineStyle.single.rawValue, range: textRange)
        cell.oldCostLabel.attributedText = attributedText
        
        if (cells[indexPath.row].discount_formatted == "0%" || cells[indexPath.row].discount_formatted == nil) {
            cell.discountLabel.isHidden = true
        } else {
            let discountPercent = cells[indexPath.row].discount_formatted ?? "10%"
            let discountPercentFinal = " -" + discountPercent + " "
            cell.discountLabel.text = discountPercentFinal
            cell.discountLabel.isHidden = false
        }
        
        cell.costLabel.text = cells[indexPath.row].price_formatted
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedCarouselProduct = cells[indexPath.row]
        carouselProductsDelegate?.sendStructSelectedCarouselProduct(product: selectedCarouselProduct)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if GlobalHelper.DeviceType.IS_IPHONE_5 {
            return CGSize(width: CarouselConstants.carouselItemSlowWidth, height: frame.height * 0.73)
        } else {
            return CGSize(width: CarouselConstants.carouselItemWidth, height: frame.height * 0.73)
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
