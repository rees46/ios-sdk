import UIKit

class CarouselCollectionViewCell: UICollectionViewCell {
    
    static let reuseId = "CarouselCollectionViewCell"
    var sdk: PersonalizationSDK!
    
    let mainImageView: UIImageView = {
       let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    let nameLabel: UILabel = {
        let label = UILabel()
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            label.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 16)
        } else {
            label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        }
        label.textColor = #colorLiteral(red: 0.007841579616, green: 0.007844132371, blue: 0.007841020823, alpha: 1)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let smallDescriptionLabel: UILabel = {
        let label = UILabel()
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            label.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 14)
        } else {
            label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        }
        label.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let likeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "like")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let oldCostLabel: UILabel = {
        let label = UILabel()
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            label.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 14)
        } else {
            label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        }
        label.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let costLabel: UILabel = {
        let label = UILabel()
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            label.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 18)
        } else {
            label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        }
        label.textColor = #colorLiteral(red: 0.007841579616, green: 0.007844132371, blue: 0.007841020823, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let discountLabel: UILabel = {
        let label = UILabel()
        label.frame = CGRect(x: 0, y: 0, width: 45, height: 20)
        if SdkConfiguration.stories.slideProductsHideButtonFontNameChanged != nil {
            
            label.font = UIFont(name: (SdkConfiguration.stories.slideProductsHideButtonFontNameChanged)!, size: 13)
        } else {
            label.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        }
        label.textColor = .white
        label.backgroundColor = UIColor(red: 0.925, green: 0.282, blue: 0.6, alpha: 1)
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(mainImageView)
        addSubview(nameLabel)
        //addSubview(smallDescriptionLabel)
        //addSubview(likeImageView)
        addSubview(oldCostLabel)
        addSubview(discountLabel)
        addSubview(costLabel)
        
        backgroundColor = .white
        //backgroundColor = .clear
        
        mainImageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        mainImageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        mainImageView.topAnchor.constraint(equalTo: topAnchor, constant: 20).isActive = true
        mainImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 1/2).isActive = true
        //mainImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 3/5).isActive = true
        
        nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        nameLabel.topAnchor.constraint(equalTo: mainImageView.bottomAnchor, constant: 12).isActive = true
        
        //smallDescriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        //smallDescriptionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8).isActive = true
        //smallDescriptionLabel.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1/2, constant: 10).isActive = true
        
        //likeImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        //likeImageView.topAnchor.constraint(equalTo: smallDescriptionLabel.bottomAnchor, constant: 30).isActive = true
        //likeImageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        //likeImageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        oldCostLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        oldCostLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 14).isActive = true
        
        discountLabel.leadingAnchor.constraint(equalTo: oldCostLabel.trailingAnchor, constant: 10).isActive = true
        discountLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 11).isActive = true
        discountLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        //discountLabel.topAnchor.constraint(equalTo: oldCostLabel.trailingAnchor, constant: 6).isActive = true
        
        costLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        costLabel.topAnchor.constraint(equalTo: oldCostLabel.bottomAnchor, constant: 8).isActive = true
        //costLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor).isActive = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layer.cornerRadius = 7
        //self.layer.shadowRadius = 9
        //layer.shadowOpacity = 0.3
        //layer.shadowOffset = CGSize(width: 5, height: 8)
        self.clipsToBounds = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
