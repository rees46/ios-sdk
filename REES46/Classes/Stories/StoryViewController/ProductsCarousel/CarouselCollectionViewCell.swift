import UIKit

class CarouselCollectionViewCell: UICollectionViewCell {
    
    static let reuseCarouselId = "CarouselCollectionViewCell"
    
    let carouselMainImageView: UIImageView = {
        let carouselProductImageView = UIImageView()
        carouselProductImageView.translatesAutoresizingMaskIntoConstraints = false
        carouselProductImageView.contentMode = .scaleAspectFit
        return carouselProductImageView
    }()
    
    let carouselProductNameLabel: UILabel = {
        let cLabel = UILabel()
        
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            cLabel.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 16)
        } else {
            cLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        }
        
        cLabel.textColor = #colorLiteral(red: 0.007841579616, green: 0.007844132371, blue: 0.007841020823, alpha: 1)
        cLabel.numberOfLines = 0
        cLabel.translatesAutoresizingMaskIntoConstraints = false
        return cLabel
    }()
    
    let carouselDescriptionLabel: UILabel = {
        let cLabel = UILabel()
        
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            cLabel.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 14)
        } else {
            cLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        }
        
        cLabel.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        cLabel.numberOfLines = 0
        cLabel.translatesAutoresizingMaskIntoConstraints = false
        return cLabel
    }()
    
    let carouselLikeImageView: UIImageView = {
        let carouselLikeImageView = UIImageView()
        carouselLikeImageView.image = UIImage(named: "iconLikeHeart")
        carouselLikeImageView.translatesAutoresizingMaskIntoConstraints = false
        return carouselLikeImageView
    }()
    
    let carouselOldCostLabel: UILabel = {
        let cLabel = UILabel()
        
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            cLabel.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 14)
        } else {
            cLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        }
        
        cLabel.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        cLabel.translatesAutoresizingMaskIntoConstraints = false
        return cLabel
    }()
    
    let carouselNowCostLabel: UILabel = {
        let cLabel = UILabel()
        
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            cLabel.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 18)
        } else {
            cLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        }
        
        cLabel.textColor = #colorLiteral(red: 0.007841579616, green: 0.007844132371, blue: 0.007841020823, alpha: 1)
        cLabel.translatesAutoresizingMaskIntoConstraints = false
        return cLabel
    }()
    
    let carouselDiscountLabel: UILabel = {
        let cLabel = UILabel()
        cLabel.frame = CGRect(x: 0, y: 0, width: 45, height: 20)
        
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            cLabel.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 13)
        } else {
            cLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        }
        
        cLabel.textColor = .white
        cLabel.backgroundColor = UIColor(red: 0.925, green: 0.282, blue: 0.6, alpha: 1)
        cLabel.layer.cornerRadius = 3
        cLabel.layer.masksToBounds = true
        cLabel.translatesAutoresizingMaskIntoConstraints = false
        return cLabel
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(carouselMainImageView)
        addSubview(carouselProductNameLabel)
        addSubview(carouselOldCostLabel)
        addSubview(carouselDiscountLabel)
        addSubview(carouselNowCostLabel)
        
        backgroundColor = .white
        
        carouselMainImageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        carouselMainImageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        carouselMainImageView.topAnchor.constraint(equalTo: topAnchor, constant: 20).isActive = true
        carouselMainImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 1/2).isActive = true
        
        carouselProductNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        carouselProductNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8).isActive = true
        carouselProductNameLabel.topAnchor.constraint(equalTo: carouselMainImageView.bottomAnchor, constant: 12).isActive = true
        
        carouselOldCostLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        carouselOldCostLabel.topAnchor.constraint(equalTo: carouselProductNameLabel.bottomAnchor, constant: 14).isActive = true
        
        carouselDiscountLabel.leadingAnchor.constraint(equalTo: carouselOldCostLabel.trailingAnchor, constant: 10).isActive = true
        carouselDiscountLabel.topAnchor.constraint(equalTo: carouselProductNameLabel.bottomAnchor, constant: 11).isActive = true
        carouselDiscountLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        carouselNowCostLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        carouselNowCostLabel.topAnchor.constraint(equalTo: carouselOldCostLabel.bottomAnchor, constant: 8).isActive = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = 7
        self.clipsToBounds = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
