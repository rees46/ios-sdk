import UIKit

class StoriesCollectionViewPreviewCell: UICollectionViewCell {
    
    static let cellId = "NewStoriesPreviewCellId"
    
    var storyImage = UIImageView()
    let storyBackCircle = UIView()
    let storyWhiteBackCircle = UIView()
    let storySuperClearBackCircle = UIView()
    let storyAuthorNameLabel = UILabel()
    let pinSymbolView = UIView()
    let pinSymbolLabel = UILabel()
    
    private var task: URLSessionDataTask?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let bgColor = UIColor(red: 214/255, green: 214/255, blue: 214/255, alpha: 214/255)
        
        storyBackCircle.backgroundColor = bgColor
        storyBackCircle.contentMode = .scaleToFill
        storyBackCircle.isUserInteractionEnabled = true
        storyBackCircle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(storyBackCircle)
        
        storyWhiteBackCircle.backgroundColor = bgColor
        storyWhiteBackCircle.contentMode = .scaleToFill
        storyWhiteBackCircle.isHidden = true
        storyWhiteBackCircle.translatesAutoresizingMaskIntoConstraints = false
        storyBackCircle.addSubview(storyWhiteBackCircle)
        
        storySuperClearBackCircle.backgroundColor = .white
        storySuperClearBackCircle.contentMode = .scaleToFill
        storySuperClearBackCircle.isHidden = true
        storySuperClearBackCircle.translatesAutoresizingMaskIntoConstraints = false
        storyBackCircle.addSubview(storySuperClearBackCircle)
        
        storyImage.backgroundColor = bgColor
        storyImage.alpha = 1.0
        storyImage.contentMode = .scaleAspectFit
        storyImage.layer.masksToBounds = true
        storyImage.translatesAutoresizingMaskIntoConstraints = false
        storySuperClearBackCircle.addSubview(storyImage)
        
        storyAuthorNameLabel.textAlignment = .center
        storyAuthorNameLabel.numberOfLines = 2
        storyAuthorNameLabel.lineBreakMode = .byWordWrapping
        storyAuthorNameLabel.font = .systemFont(ofSize: 17)
        storyAuthorNameLabel.translatesAutoresizingMaskIntoConstraints = false
        storyAuthorNameLabel.backgroundColor = bgColor
        addSubview(storyAuthorNameLabel)
        
        pinSymbolView.backgroundColor = .white
        pinSymbolView.translatesAutoresizingMaskIntoConstraints = false
        pinSymbolView.isHidden = true
        addSubview(pinSymbolView)
        
        pinSymbolLabel.text = ""
        pinSymbolLabel.translatesAutoresizingMaskIntoConstraints = false
        pinSymbolView.addSubview(pinSymbolLabel)
   
        makeConstraints()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        task?.cancel()
    }
    
    public func configure(story: Story) {
        setImage(imagePath: story.avatar)
        storyAuthorNameLabel.text = "\(story.name)"
        pinSymbolView.isHidden = !story.pinned
    }
    
    func configureCell(settings: StoriesSettings?, viewed: Bool, viewedLocalKey: Bool) {
        storyWhiteBackCircle.isHidden = false
        storySuperClearBackCircle.isHidden = false
        layoutIfNeeded()
        
        if let settings = settings {
            var labelColor = settings.color.hexToRGB()
            if #available(iOS 12.0, *) {
                if self.traitCollection.userInterfaceStyle == .dark {
                    labelColor = "#FFFFFF".hexToRGB()
                }
            }
            
            storyAuthorNameLabel.textColor = UIColor(red: labelColor.red, green: labelColor.green, blue: labelColor.blue, alpha: 1)
            storyAuthorNameLabel.font = .systemFont(ofSize: CGFloat(settings.fontSize))
            storyAuthorNameLabel.backgroundColor = .clear
            
            storyBackCircle.backgroundColor = .white
            let pinBgColor = settings.backgroundPin.hexToRGB()
            pinSymbolView.backgroundColor = UIColor(red: pinBgColor.red, green: pinBgColor.green, blue: pinBgColor.blue, alpha: 1)
            pinSymbolLabel.text = settings.pinSymbol
            
            let storiesViewdBg = settings.borderViewed.hexToRGB()
            let storiesNotViewBg = settings.borderNotViewed.hexToRGB()
            
            if (viewed) {
                storyWhiteBackCircle.backgroundColor = viewed ?
                UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1) :
                UIColor(red: storiesNotViewBg.red, green: storiesNotViewBg.green, blue: storiesNotViewBg.blue, alpha: 1)
            } else {
                storyWhiteBackCircle.backgroundColor = viewedLocalKey ?
                UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1) :
                UIColor(red: storiesNotViewBg.red, green: storiesNotViewBg.green, blue: storiesNotViewBg.blue, alpha: 1)
            }
            storyWhiteBackCircle.layer.cornerRadius = storyWhiteBackCircle.frame.width / 2
            storyWhiteBackCircle.layer.masksToBounds = true
            
            if (viewed || viewedLocalKey) {
                storyImage.alpha = 0.75
            } else {
                storyImage.alpha = 1.0
            }
            
            storySuperClearBackCircle.backgroundColor = .white
            storySuperClearBackCircle.alpha = 1.0
            storySuperClearBackCircle.layer.cornerRadius = storySuperClearBackCircle.frame.width / 2
            storySuperClearBackCircle.layer.masksToBounds = true
        } else {
            storyImage.alpha = 1.0
            storyAuthorNameLabel.textColor = .black
            storyBackCircle.backgroundColor = .white
            storyWhiteBackCircle.backgroundColor = .white
            storySuperClearBackCircle.backgroundColor = .white
            pinSymbolView.isHidden = true
        }
    }
    
    private func setImage(imagePath: String) {
        guard let url = URL(string: imagePath) else {
            return
        }
        
        self.storyImage.load.request(with: url)
    }
    
    private func makeConstraints() {
        
        storyBackCircle.topAnchor.constraint(equalTo: topAnchor).isActive = true
        storyBackCircle.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        storyBackCircle.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        storyBackCircle.heightAnchor.constraint(equalTo: storyBackCircle.widthAnchor).isActive = true
        
        storyWhiteBackCircle.topAnchor.constraint(equalTo: storyBackCircle.topAnchor, constant: 1).isActive = true
        storyWhiteBackCircle.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant: 1).isActive = true
        storyWhiteBackCircle.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: -1).isActive = true
        storyWhiteBackCircle.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: -1).isActive = true
        
        storySuperClearBackCircle.topAnchor.constraint(equalTo: storyBackCircle.topAnchor, constant: 3.8).isActive = true
        storySuperClearBackCircle.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant: 3.8).isActive = true
        storySuperClearBackCircle.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: -3.8).isActive = true
        storySuperClearBackCircle.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: -3.8).isActive = true
        
        storyImage.topAnchor.constraint(equalTo: storyWhiteBackCircle.topAnchor, constant: 5.5).isActive = true
        storyImage.leadingAnchor.constraint(equalTo: storyWhiteBackCircle.leadingAnchor, constant: 5.5).isActive = true
        storyImage.trailingAnchor.constraint(equalTo: storyWhiteBackCircle.trailingAnchor, constant: -5.5).isActive = true
        storyImage.bottomAnchor.constraint(equalTo: storyWhiteBackCircle.bottomAnchor, constant: -5.5).isActive = true
        
        storyAuthorNameLabel.topAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: 8).isActive = true
        storyAuthorNameLabel.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor,constant: -10).isActive = true
        storyAuthorNameLabel.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: 10).isActive = true
        
        pinSymbolView.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor).isActive = true
        pinSymbolView.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: -4).isActive = true
        pinSymbolView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        pinSymbolView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        
        pinSymbolLabel.centerXAnchor.constraint(equalTo: pinSymbolView.centerXAnchor).isActive = true
        pinSymbolLabel.centerYAnchor.constraint(equalTo: pinSymbolView.centerYAnchor).isActive = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        storyBackCircle.layer.cornerRadius = storyBackCircle.frame.width / 2
        storyImage.layer.cornerRadius = storyImage.frame.width / 2
        storyWhiteBackCircle.layer.cornerRadius = storyWhiteBackCircle.frame.width / 2
        storySuperClearBackCircle.layer.cornerRadius = storySuperClearBackCircle.frame.width / 2
        pinSymbolView.layer.cornerRadius = pinSymbolView.frame.width / 2
        
        if storyImage.image == nil {
            storyBackCircle.layer.cornerRadius = bounds.width / 2
        }
    }
}

