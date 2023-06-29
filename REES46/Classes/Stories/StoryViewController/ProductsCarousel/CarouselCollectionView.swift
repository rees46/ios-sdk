import UIKit
import WebKit

class CarouselCollectionView: UICollectionView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var cells = [StoriesProduct]()
    
    public weak var productsDelegate: CarouselCollectionViewCellDelegate?
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        super.init(frame: .zero, collectionViewLayout: layout)
        
        backgroundColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 204/255)
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
        
//        NSLayoutConstraint.activate([
//            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 9),
//            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -9),
//            //stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
//            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 22),
//            stackView.heightAnchor.constraint(equalToConstant: 52)
//        ])
        
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
                stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 18),
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
        
        //let button = UIButton(frame: CGRect(x: stackView.frame.origin.x, y: stackView.frame.origin.y, width: stackView.frame.width, height: 52))
        
        //let button = UIButton(frame: CGRect(x: 0, y: 0, width: 155, height: 52))
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 85, height: 40))
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.setTitle("Скрыть товары", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        button.backgroundColor = .white
        button.setTitleColor(UIColor.black, for: .normal)
        
        button.layer.cornerRadius = button.frame.size.height / 2
        //button.layer.borderWidth = 1.2
        //button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(self.buttonTapped), for: .touchUpInside)
        //button.layer.borderColor = UIColor.black.cgColor
        
        var mainBundle = Bundle(for: classForCoder)
    #if SWIFT_PACKAGE
        mainBundle = Bundle.module
    #endif
        let image = UIImage(named: "angleDown", in: mainBundle, compatibleWith: nil)
        //addRightIcon(image: image!)
        
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
        
//         NSLayoutConstraint.activate([
//            //button.topAnchor.constraint(equalTo: stackView.topAnchor),
//            button.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
//            button.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
//            button.trailingAnchor.constraint(equalTo: stackView.trailingAnchor)
//         ])
        
        stackView.addArrangedSubview(button)// addSubview(button)
        addSubview(stackView)
        
       
        
        

                // Setup label and add to stack view
//                 titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
//                 stackView.addArrangedSubview(titleLabel)
//
//                 // Set button image
//                 let largeConfig = UIImage.SymbolConfiguration(scale: .large)
//                 let infoImage = UIImage(systemName: "info.circle.fill", withConfiguration: largeConfig)?.withTintColor(.systemPink, renderingMode: .alwaysOriginal)
//                 infoButton.setImage(infoImage, for: .normal)
//
//                 // Set button action
//                 infoButton.addAction(UIAction(handler: { [unowned self] (_) in
//                     // Trigger callback when button tapped
//                     self.infoButtonDidTappedCallback?()
//                 }), for: .touchUpInside)
//
//                 // Add button to stack view
//                 stackView.addArrangedSubview(infoButton)
        
        
        
        
        
//         NSLayoutConstraint(item: button, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1, constant: -10).isActive = true
//         NSLayoutConstraint(item: button, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: pageIndicator, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 26).isActive = true
//         NSLayoutConstraint(item: button, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 30).isActive = true
//         NSLayoutConstraint(item: button, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 30).isActive = true
    }
    
    @objc func buttonTapped(sender : UIButton) {
        productsDelegate?.closeProductsCarousel()
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
        
        let mainProductText = cells[indexPath.row].oldprice
        let textRange = NSMakeRange(0, mainProductText!.count)
        let attributedText = NSMutableAttributedString(string: mainProductText!)
        attributedText.addAttribute(NSAttributedString.Key.strikethroughStyle , value: NSUnderlineStyle.single.rawValue, range: textRange)
        cell.oldCostLabel.attributedText = attributedText
        
        let discountPercent = " "  + (cells[indexPath.row].discount ?? "10") + "% "
        cell.discountLabel.text = discountPercent // cells[indexPath.row].discount
        //cell.oldCostLabel.text = cells[indexPath.row].oldprice// "$\(cells[indexPath.row].price)"
        
        cell.costLabel.text = cells[indexPath.row].price// "$\(cells[indexPath.row].price)"
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        //let selectedProductUrl = URL(string: cells[indexPath.row].url)!
        productsDelegate?.didTapLinkIosOpeningExternal(url: cells[indexPath.row].url)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CarouselConstants.carouselItemWidth, height: frame.height * 0.73)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


extension UIView {
    func layerGradient() {
        let layer : CAGradientLayer = CAGradientLayer()
        layer.frame.size = self.frame.size
        layer.frame.origin = CGPointMake(0.0,0.0)
        layer.cornerRadius = CGFloat(frame.width / 20)

        let color0 = UIColor(red:250.0/255, green:250.0/255, blue:250.0/255, alpha:0.5).cgColor
        let color1 = UIColor(red:200.0/255, green:200.0/255, blue: 200.0/255, alpha:0.1).cgColor
        let color2 = UIColor(red:150.0/255, green:150.0/255, blue: 150.0/255, alpha:0.1).cgColor
        let color3 = UIColor(red:100.0/255, green:100.0/255, blue: 100.0/255, alpha:0.1).cgColor
        let color4 = UIColor(red:50.0/255, green:50.0/255, blue:50.0/255, alpha:0.1).cgColor
        let color5 = UIColor(red:0.0/255, green:0.0/255, blue:0.0/255, alpha:0.1).cgColor
        let color6 = UIColor(red:150.0/255, green:150.0/255, blue:150.0/255, alpha:0.1).cgColor

        layer.colors = [color0,color1,color2,color3,color4,color5,color6]
        self.layer.insertSublayer(layer, at: 0)
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
