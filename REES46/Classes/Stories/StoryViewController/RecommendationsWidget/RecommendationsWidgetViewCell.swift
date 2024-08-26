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
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    let recommendationsDiscountLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.backgroundColor = UIColor(red: 175/255, green: 82/255, blue: 222/255, alpha: 1)
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let recommendationsCreditLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.backgroundColor = UIColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1)
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var recommendationsRatingStars: RecommendationsStarsView = {
        let starsView = RecommendationsStarsView()
        starsView.starsSetupSettings.filledImage = UIImage(named: "starFilled")?.withRenderingMode(.alwaysOriginal)
        starsView.starsSetupSettings.emptyImage = UIImage(named: "starEmpty")?.withRenderingMode(.alwaysOriginal)
        starsView.rating = 0
        starsView.starsSetupSettings.fillMode = .half
        starsView.starsSetupSettings.reloadOnUserTouch = false
        starsView.translatesAutoresizingMaskIntoConstraints = false
        return starsView
    }()
    
    let recommendationsRatingStarsNoReviewsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = #colorLiteral(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let recommendationsRatingLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = #colorLiteral(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let recommendationsProductNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.numberOfLines = 3
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let recommendationsClearLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let recommendationsOldPrice: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let recommendationsPriceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        let tapCellPosition: CGPoint = sender.convert(CGPoint.zero, to: self)
        widgetCellDelegate?.didTapWidgetAddToCartButtonInside(cell: self, position: tapCellPosition)
    }
    
    @objc
    public func didAddToFavoritesTapButton(_ sender: AnyObject) {
        let tapFavCellPosition: CGPoint = sender.convert(CGPoint.zero, to: self)
        widgetCellDelegate?.didTapWidgetAddToFavoritesButtonInside(cell: self, position: tapFavCellPosition)
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        recommendationsCartButton.addTarget(self, action: #selector(didAddToCartTapButton(_:)), for: .touchUpInside)
        
        recommendationsFavoritesButton.addTarget(self, action: #selector(didAddToFavoritesTapButton(_:)), for: .touchUpInside)
        
        contentView.addSubview(recommendationsImageView)
        contentView.addSubview(recommendationsDiscountLabel)
        contentView.addSubview(recommendationsCreditLabel)
        contentView.addSubview(recommendationsRatingStars)
        contentView.addSubview(recommendationsRatingStarsNoReviewsLabel)
        contentView.addSubview(recommendationsRatingLabel)
        contentView.addSubview(recommendationsProductNameLabel)
        contentView.addSubview(recommendationsClearLabel)
        contentView.addSubview(recommendationsOldPrice)
        contentView.addSubview(recommendationsPriceLabel)
        contentView.addSubview(recommendationsCartButton)
        contentView.addSubview(recommendationsFavoritesButton)
        
        backgroundColor = .white
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Image View
            recommendationsImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            recommendationsImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            recommendationsImageView.heightAnchor.constraint(equalToConstant: 140),
            
            // Discount Label
            recommendationsDiscountLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            recommendationsDiscountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsDiscountLabel.widthAnchor.constraint(equalToConstant: 55),
            recommendationsDiscountLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Credit Label
            recommendationsCreditLabel.topAnchor.constraint(equalTo: recommendationsDiscountLabel.bottomAnchor, constant: 7),
            recommendationsCreditLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsCreditLabel.widthAnchor.constraint(equalToConstant: 55),
            recommendationsCreditLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Product Name
            recommendationsProductNameLabel.topAnchor.constraint(equalTo: recommendationsImageView.bottomAnchor, constant: 10),
            recommendationsProductNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsProductNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Rating Stars
            recommendationsRatingStars.topAnchor.constraint(equalTo: recommendationsProductNameLabel.bottomAnchor, constant: 10),
            recommendationsRatingStars.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsRatingStars.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Rating Stars No Reviews
            recommendationsRatingStarsNoReviewsLabel.topAnchor.constraint(equalTo: recommendationsRatingStars.bottomAnchor, constant: 4),
            recommendationsRatingStarsNoReviewsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsRatingStarsNoReviewsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Rating Label
            recommendationsRatingLabel.topAnchor.constraint(equalTo: recommendationsRatingStarsNoReviewsLabel.bottomAnchor, constant: 0),
            recommendationsRatingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Old Price
            recommendationsOldPrice.topAnchor.constraint(equalTo: recommendationsRatingLabel.bottomAnchor, constant: 8),
            recommendationsOldPrice.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Price
            recommendationsPriceLabel.topAnchor.constraint(equalTo: recommendationsOldPrice.bottomAnchor, constant: 4),
            recommendationsPriceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Cart Button
            recommendationsCartButton.topAnchor.constraint(equalTo: recommendationsPriceLabel.bottomAnchor, constant: 10),
            recommendationsCartButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsCartButton.heightAnchor.constraint(equalToConstant: 44),
            recommendationsCartButton.widthAnchor.constraint(equalToConstant: 120),
            
            // Favorites Button
            recommendationsFavoritesButton.topAnchor.constraint(equalTo: recommendationsPriceLabel.bottomAnchor, constant: 10),
            recommendationsFavoritesButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            recommendationsFavoritesButton.widthAnchor.constraint(equalToConstant: 27),
            recommendationsFavoritesButton.heightAnchor.constraint(equalToConstant: 27),
            
            // Buttons Bottom Constraint
            recommendationsCartButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            recommendationsFavoritesButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let backgroundColor = SdkConfiguration.isDarkMode
        ? SdkConfiguration.recommendations.widgetCellBackgroundColorDarkMode.hexToRGB()
        : SdkConfiguration.recommendations.widgetCellBackgroundColor.hexToRGB()
        
        layer.backgroundColor = UIColor(red: backgroundColor.red, green: backgroundColor.green, blue: backgroundColor.blue, alpha: 1).cgColor
        layer.borderWidth = SdkConfiguration.recommendations.widgetBorderWidth
        
        let borderColor = SdkConfiguration.isDarkMode
        ? SdkConfiguration.recommendations.widgetBorderColorDarkMode.hexToRGB()
        : SdkConfiguration.recommendations.widgetBorderColor.hexToRGB()
        
        layer.borderColor = UIColor(red: borderColor.red, green: borderColor.green, blue: borderColor.blue, alpha: 1).withAlphaComponent(SdkConfiguration.recommendations.widgetBorderTransparent).cgColor
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
