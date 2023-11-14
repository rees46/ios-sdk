import UIKit

public protocol RecommendationsWidgetViewCellDelegate: AnyObject {
    func didTapWidgetAddToCartButtonInside(cell: RecommendationsWidgetViewCell, position: CGPoint)
    func didTapWidgetAddToFavoritesButtonInside(cell: RecommendationsWidgetViewCell, position: CGPoint)
}

public class RecommendationsWidgetViewCell: UICollectionViewCell {
    
    static let reuseRecommCellId = "RecommendationsWidgetViewCell"

    fileprivate let keyCellTagStarsDefaults = "key"
    
    public weak var widgetCellDelegate: RecommendationsWidgetViewCellDelegate?
    
    public let recommendationsCellWidgetIndicator = StoriesSlideReloadIndicator()
    
    let recommendationsImageView: UIImageView = {
        let rImageView = UIImageView()
        rImageView.translatesAutoresizingMaskIntoConstraints = false
        rImageView.contentMode = .scaleAspectFit
        return rImageView
    }()
    
    let recommendationsDiscountLabel: UILabel = {
        let rLabel = UILabel()
        rLabel.frame = CGRect(x: 0, y: 0, width: 55, height: 20)
        rLabel.textColor = .white
        rLabel.backgroundColor = UIColor(red: 175/255, green: 82/255, blue: 222/255, alpha: 1)
        rLabel.layer.cornerRadius = 3
        rLabel.layer.masksToBounds = true
        rLabel.translatesAutoresizingMaskIntoConstraints = false
        return rLabel
    }()
    
    let recommendationsCreditLabel: UILabel = {
        let rLabel = UILabel()
        rLabel.frame = CGRect(x: 0, y: 0, width: 55, height: 20)
        rLabel.textColor = .white
        rLabel.backgroundColor = UIColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1)
        rLabel.layer.cornerRadius = 3
        rLabel.layer.masksToBounds = true
        rLabel.translatesAutoresizingMaskIntoConstraints = false
        return rLabel
    }()
    
    lazy var recommendationsRatingStars: RecommendationsStarsView = {
        let rateStarsView = RecommendationsStarsView()
        rateStarsView.starsSetupSettings.filledImage = UIImage(named: "starFilled")?.withRenderingMode(.alwaysOriginal)
        rateStarsView.starsSetupSettings.emptyImage = UIImage(named: "starEmpty")?.withRenderingMode(.alwaysOriginal)
        rateStarsView.rating = 0
        rateStarsView.starsSetupSettings.fillMode = .half
        rateStarsView.starsSetupSettings.reloadOnUserTouch = false
        rateStarsView.translatesAutoresizingMaskIntoConstraints = false
        return rateStarsView
    }()
    
    let recommendationsRatingLabel: UILabel = {
        let rLabel = UILabel()
        rLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        rLabel.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        rLabel.translatesAutoresizingMaskIntoConstraints = false
        return rLabel
    }()
    
    let recommendationsProductNameLabel: UILabel = {
        let rLabel = UILabel()
        rLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        rLabel.textColor = .black
        
        if SdkConfiguration.isDarkMode {
            rLabel.textColor = .white
        } else {
            rLabel.textColor = .black
        }
        
        rLabel.translatesAutoresizingMaskIntoConstraints = false
        rLabel.numberOfLines = 3
        rLabel.lineBreakMode = .byWordWrapping
        rLabel.textAlignment = .left
        return rLabel
    }()
    
    let recommendationsClearLabel: UILabel = {
        let rLabel = UILabel()
        rLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        rLabel.textColor = .black
        rLabel.translatesAutoresizingMaskIntoConstraints = false
        return rLabel
    }()
    
    let recommendationsOldPrice: UILabel = {
        let rLabel = UILabel()
        rLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        
        if SdkConfiguration.isDarkMode {
            rLabel.textColor = #colorLiteral(red: 0.9289160371, green: 0.9289160371, blue: 0.9289160371, alpha: 1)
        } else {
            rLabel.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        }
        
        rLabel.numberOfLines = 0
        rLabel.translatesAutoresizingMaskIntoConstraints = false
        return rLabel
    }()
    
    let recommendationsPriceLabel: UILabel = {
        let rLabel = UILabel()
        rLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        
        if SdkConfiguration.isDarkMode {
            rLabel.textColor = .white
        } else {
            rLabel.textColor = .black
        }
        
        rLabel.numberOfLines = 0
        rLabel.translatesAutoresizingMaskIntoConstraints = false
        return rLabel
    }()
    
    let recommendationsCartButton: UIButton = {
        let rAddToCartButton = UIButton()
        rAddToCartButton.translatesAutoresizingMaskIntoConstraints = false
        rAddToCartButton.layer.cornerRadius = 6
        rAddToCartButton.layer.masksToBounds = true
        return rAddToCartButton
    }()
    
    let recommendationsFavoritesButton: UIButton = {
        let rAddToFavoritesButton = UIButton()
        rAddToFavoritesButton.translatesAutoresizingMaskIntoConstraints = false
        
        if SdkConfiguration.isDarkMode {
            rAddToFavoritesButton.tintColor = .black
            rAddToFavoritesButton.setTitleColor(.black, for: .normal)
        } else {
            rAddToFavoritesButton.tintColor = .white
            rAddToFavoritesButton.setTitleColor(.white, for: .normal)
        }
        return rAddToFavoritesButton
    }()
    
    @objc
    public func didAddToCartTapButton(_ sender: AnyObject) {
        let tapCellPosition: CGPoint = sender.convert(CGPointZero, to: self)
        widgetCellDelegate?.didTapWidgetAddToCartButtonInside(cell: self, position: tapCellPosition)
    }
    
    @objc
    public func didAddToFavoritesTapButton(_ sender: AnyObject) {
        //let tapFavCellPosition = sender.location(in: self.contentView)
        let tapFavCellPosition: CGPoint = sender.convert(CGPointZero, to: self)
        widgetCellDelegate?.didTapWidgetAddToFavoritesButtonInside(cell: self, position: tapFavCellPosition)
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        recommendationsCartButton.addTarget(self, action: #selector(didAddToCartTapButton(_:)), for: .touchUpInside)
        
        recommendationsFavoritesButton.addTarget(self, action: #selector(didAddToFavoritesTapButton(_:)), for: .touchUpInside)
        
        addSubview(recommendationsImageView)
        addSubview(recommendationsDiscountLabel)
        addSubview(recommendationsCreditLabel)
        addSubview(recommendationsRatingStars)
        addSubview(recommendationsRatingLabel)
        addSubview(recommendationsProductNameLabel)
        addSubview(recommendationsClearLabel)
        addSubview(recommendationsOldPrice)
        addSubview(recommendationsPriceLabel)
        addSubview(recommendationsCartButton)
        addSubview(recommendationsFavoritesButton)
        
        backgroundColor = .white
        
//        let customCellPreloadIndicatorColor = SdkConfiguration.recommendations.storiesSlideReloadIndicatorBackgroundColor.hexToRGB()
//        recommendationsCellWidgetIndicator.strokeColor = UIColor(red: customCellPreloadIndicatorColor.red, green: customCellPreloadIndicatorColor.green, blue: customCellPreloadIndicatorColor.blue, alpha: 1)
//        recommendationsCellWidgetIndicator.contentMode = .scaleToFill
//        recommendationsCellWidgetIndicator.lineWidth = SdkConfiguration.stories.storiesSlideReloadIndicatorBorderLineWidth
//        recommendationsCellWidgetIndicator.numSegments = SdkConfiguration.stories.storiesSlideReloadIndicatorSegmentCount
//        recommendationsCellWidgetIndicator.animationDuration = SdkConfiguration.stories.storiesSlideReloadIndicatorAnimationDuration
//        recommendationsCellWidgetIndicator.rotationDuration = SdkConfiguration.stories.storiesSlideReloadIndicatorRotationDuration
//        recommendationsCellWidgetIndicator.alpha = 1.0
//        addSubview(recommendationsCellWidgetIndicator)
//        
//        recommendationsCellWidgetIndicator.translatesAutoresizingMaskIntoConstraints = false
//        recommendationsCellWidgetIndicator.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
//        recommendationsCellWidgetIndicator.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
//        recommendationsCellWidgetIndicator.startAnimating()
        
        saveWidgetStarRating()
        loadWidgetStarRating()
        
        recommendationsImageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        recommendationsImageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        recommendationsImageView.topAnchor.constraint(equalTo: topAnchor, constant: 9).isActive = true
        recommendationsImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 2.34/5).isActive = true
        
        recommendationsDiscountLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13).isActive = true
        recommendationsDiscountLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12).isActive = true
        recommendationsDiscountLabel.heightAnchor.constraint(equalToConstant: 23).isActive = true
        
        recommendationsCreditLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12).isActive = true
        recommendationsCreditLabel.topAnchor.constraint(equalTo: recommendationsDiscountLabel.bottomAnchor, constant: 7).isActive = true
        recommendationsCreditLabel.heightAnchor.constraint(equalToConstant: 23).isActive = true
        
        recommendationsCreditLabel.isHidden = true //coming soon
        recommendationsDiscountLabel.isHidden = true //coming soon
        
        recommendationsRatingStars.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15).isActive = true
        recommendationsRatingStars.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        recommendationsRatingStars.topAnchor.constraint(equalTo: recommendationsImageView.bottomAnchor, constant: 8).isActive = true
        
        recommendationsRatingLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 140).isActive = true
        recommendationsRatingLabel.topAnchor.constraint(equalTo: recommendationsImageView.bottomAnchor, constant: 10).isActive = true
        
        recommendationsProductNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14).isActive = true
        recommendationsProductNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14).isActive = true
        //recommendationsProductNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        recommendationsProductNameLabel.topAnchor.constraint(equalTo: recommendationsRatingStars.bottomAnchor, constant: 8).isActive = true
        
        recommendationsClearLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14).isActive = true
        recommendationsClearLabel.topAnchor.constraint(equalTo: recommendationsProductNameLabel.bottomAnchor, constant: 8).isActive = true
        
        recommendationsOldPrice.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14).isActive = true
        recommendationsOldPrice.topAnchor.constraint(equalTo: recommendationsPriceLabel.topAnchor, constant: -20).isActive = true
        
        recommendationsPriceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14).isActive = true
        recommendationsPriceLabel.topAnchor.constraint(equalTo: recommendationsCartButton.topAnchor, constant: -32).isActive = true
        
        recommendationsCartButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14).isActive = true
        recommendationsCartButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -13).isActive = true
        recommendationsCartButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 2/3).isActive = true
        recommendationsCartButton.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 1/10).isActive = true
        
        if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO || SdkGlobalHelper.DeviceType.IS_IPHONE_XS || SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
            recommendationsFavoritesButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14).isActive = true
            recommendationsFavoritesButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -21).isActive = true
            recommendationsFavoritesButton.widthAnchor.constraint(equalToConstant: 27).isActive = true
            recommendationsFavoritesButton.heightAnchor.constraint(equalToConstant: 27).isActive = true
        } else {
            recommendationsFavoritesButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18).isActive = true
            recommendationsFavoritesButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -21).isActive = true
            recommendationsFavoritesButton.widthAnchor.constraint(equalToConstant: 27).isActive = true
            recommendationsFavoritesButton.heightAnchor.constraint(equalToConstant: 27).isActive = true
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        var widgetCellBackgroundColor = SdkConfiguration.recommendations.widgetCellBackgroundColor.hexToRGB()
        if SdkConfiguration.isDarkMode {
            widgetCellBackgroundColor = SdkConfiguration.recommendations.widgetCellBackgroundColorDarkMode.hexToRGB()
        }
        layer.backgroundColor = UIColor(red: widgetCellBackgroundColor.red, green: widgetCellBackgroundColor.green, blue: widgetCellBackgroundColor.blue, alpha: 1).cgColor
        
        layer.masksToBounds = true
        layer.borderWidth = SdkConfiguration.recommendations.widgetBorderWidth
        
        var widgetCellBorderColor = SdkConfiguration.recommendations.widgetBorderColor.hexToRGB()
        if SdkConfiguration.isDarkMode {
            widgetCellBorderColor = SdkConfiguration.recommendations.widgetBorderColorDarkMode.hexToRGB()
        }
        layer.borderColor = UIColor(red: widgetCellBorderColor.red, green: widgetCellBorderColor.green, blue: widgetCellBorderColor.blue, alpha: 1).withAlphaComponent(SdkConfiguration.recommendations.widgetBorderTransparent).cgColor
        
        layer.cornerRadius = SdkConfiguration.recommendations.widgetCornerRadius
    }
    
    func saveWidgetStarRating() {
        recommendationsRatingStars.didFinishTouchingRecommendationsStars = { stRating in
            UserDefaults.standard.set(stRating, forKey: self.keyCellTagStarsDefaults)
        }
    }
        
    func loadWidgetStarRating() {
        guard let rLoadedStarValue = UserDefaults.standard.object(forKey: keyCellTagStarsDefaults) as? Double else {return}
        recommendationsRatingStars.rating = rLoadedStarValue
    }
    
    override public func prepareForReuse() {
        recommendationsRatingStars.prepareForReuse()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ rating: Double) {
        recommendationsRatingStars.rating = rating
    }
}
