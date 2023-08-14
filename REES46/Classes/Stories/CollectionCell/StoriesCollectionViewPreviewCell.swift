import UIKit

class StoriesCollectionViewPreviewCell: UICollectionViewCell, SdkStyleCustomColorSchemeAwareView, SdkStyleCustomFontsAwareView {
    
    static let cellId = "NewStoriesPreviewCellId"
    
    var storyImage = UIImageView()
    let storyBackCircle = UIView()
    let storyWhiteBackCircle = UIView()
    let storySuperClearBackCircle = UIView()
    let storyAuthorNameLabel = UILabel()
    let pinSymbolView = UIView()
    let pinSymbolLabel = UILabel()
    let preloadIndicator = StoriesPreloadIndicator()
    
    private var task: URLSessionDataTask?
    var sdk: PersonalizationSDK!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let bgColor = UIColor(red: 214/255, green: 214/255, blue: 214/255, alpha: 214/255)
        storyBackCircle.backgroundColor = .clear
        storyBackCircle.contentMode = .scaleToFill
        storyBackCircle.isUserInteractionEnabled = true
        storyBackCircle.translatesAutoresizingMaskIntoConstraints = false
        storyBackCircle.alpha = 1.0
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
        
        storyImage.isHidden = false
        storyImage.backgroundColor = bgColor
        storyImage.alpha = 0.0
        storyImage.contentMode = .scaleAspectFit
        storyImage.layer.masksToBounds = true
        storyImage.translatesAutoresizingMaskIntoConstraints = false
        storySuperClearBackCircle.addSubview(storyImage)
        
        preloadIndicator.contentMode = .scaleToFill
        preloadIndicator.translatesAutoresizingMaskIntoConstraints = false
        preloadIndicator.animationDuration = Double(Int.random(in: 2..<3))
        preloadIndicator.rotationDuration = 7
        preloadIndicator.numSegments = Int(Double(Int.random(in: 9..<17)))
        preloadIndicator.lineWidth = 3.9
        preloadIndicator.alpha = 0
        storyWhiteBackCircle.addSubview(preloadIndicator)
        
        storyAuthorNameLabel.textAlignment = .center
        storyAuthorNameLabel.numberOfLines = 2
        storyAuthorNameLabel.lineBreakMode = .byWordWrapping
        //storyAuthorNameLabel.font = .boldSystemFont(ofSize: 23)
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
        setImage(imagePathSdk: story.avatar)
        storyAuthorNameLabel.text = "\(story.name)"
        pinSymbolView.isHidden = !story.pinned
    }
    
    func configureCell(settings: StoriesSettings?, viewed: Bool, viewedLocalKey: Bool, storyId: Int) {
        storyWhiteBackCircle.isHidden = false
        storySuperClearBackCircle.isHidden = false
        layoutIfNeeded()
        
        if let settings = settings {
            storyAuthorNameLabel.font = SdkStyle.shared.currentColorScheme?.storiesBlockSelectFontName.withSize(SdkStyle.shared.currentColorScheme!.storiesBlockSelectFontSize)
            let labelColor = settings.color.hexToRGB()
//            //DEPRECATED
//            if #available(iOS 12.0, *) {
//                if self.traitCollection.userInterfaceStyle == .dark {
//                    labelColor = "#ffffff".hexToRGB()
//                }
//            }
//            storyAuthorNameLabel.font = .systemFont(ofSize: CGFloat(settings.fontSize))
//            storyAuthorNameLabel.textColor = UIColor(red: labelColor.red, green: labelColor.green, blue: labelColor.blue, alpha: 1)
            
            preloadIndicator.strokeColor = .white
            storyAuthorNameLabel.backgroundColor = .clear
            
            if (SdkStyle.shared.currentColorScheme?.storiesBlockFontColor == UIColor.sdkDefaultBlackColor) {
                storyAuthorNameLabel.textColor = UIColor(red: labelColor.red, green: labelColor.green, blue: labelColor.blue, alpha: 1)
            } else {
                //storyAuthorNameLabel.textColor = SdkStyle.shared.currentColorScheme?.storiesBlockFontColor
                if #available(iOS 12.0, *) {
                    if self.traitCollection.userInterfaceStyle == .dark {
                        storyAuthorNameLabel.textColor = SdkConfiguration.stories.storiesBlockTextColorChanged_Dark
                    } else {
                        storyAuthorNameLabel.textColor = SdkConfiguration.stories.storiesBlockTextColorChanged_Light
                    }
                } else {
                    storyAuthorNameLabel.textColor = .black
                }
            }
            
            if SdkConfiguration.stories.storiesBlockFontNameChanged != nil {
                if SdkConfiguration.stories.storiesBlockMinimumFontSizeChanged != nil {
                    storyAuthorNameLabel.font = SdkStyle.shared.currentColorScheme?.storiesBlockSelectFontName.withSize(SdkStyle.shared.currentColorScheme!.storiesBlockSelectFontSize)
                    //storyAuthorNameLabel.font = SdkDynamicFont.dynamicFont(textStyle: .title1, weight: .light)
                } else {
                    //let test = SdkDynamicFont.dynamicFont(textStyle: .title3)
                    //storyAuthorNameLabel.font = SdkDynamicFont.dynamicFont(textStyle: .title3, weight: .bold)
                    storyAuthorNameLabel.font = SdkStyle.shared.currentColorScheme?.storiesBlockSelectFontName
                }
            } else {
                if SdkConfiguration.stories.storiesBlockMinimumFontSizeChanged != 0.0 {
                    let size = SdkStyle.shared.currentColorScheme?.storiesBlockSelectFontSize ?? 15.0
                    //storyAuthorNameLabel.font = SdkDynamicFont.dynamicFont(textStyle: .title2, weight: .bold)// .systemFont(ofSize: size)
                    storyAuthorNameLabel.font = .systemFont(ofSize: CGFloat(size))
                } else {
                    storyAuthorNameLabel.font = .systemFont(ofSize: CGFloat(settings.fontSize))
                }
            }
            
            storyBackCircle.backgroundColor = .white
            let pinBgColor = settings.backgroundPin.hexToRGB()
            pinSymbolView.backgroundColor = UIColor(red: pinBgColor.red, green: pinBgColor.green, blue: pinBgColor.blue, alpha: 1)
            pinSymbolLabel.text = settings.pinSymbol
            
            let storiesViewdBg = settings.borderViewed.hexToRGB()
            let storiesNotViewBg = settings.borderNotViewed.hexToRGB()
            
            if (viewed) {
                storyWhiteBackCircle.backgroundColor = viewed ?
                UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1) :
                UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1)
                
                preloadIndicator.strokeColor = viewed ?
                //UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1) :
                //UIColor(red: storiesNotViewBg.red, green: storiesNotViewBg.green, blue: storiesNotViewBg.blue, alpha: 1)
                UIColor(red: 255/255, green: 118/255, blue: 0/255, alpha: 1) :
                UIColor(red: 255/255, green: 118/255, blue: 0/255, alpha: 1)
            } else {
                storyWhiteBackCircle.backgroundColor = viewedLocalKey ?
                UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1) :
                UIColor(red: storiesNotViewBg.red, green: storiesNotViewBg.green, blue: storiesNotViewBg.blue, alpha: 1)
                
                preloadIndicator.strokeColor = UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1)
            }
            storyWhiteBackCircle.layer.cornerRadius = storyWhiteBackCircle.frame.width / 2
            storyWhiteBackCircle.layer.masksToBounds = true
            
            if (viewed || viewedLocalKey) {
                UIView.animate(withDuration: 1.0, animations: {
                    self.storyImage.alpha = 0.9
                })
            } else {
                UIView.animate(withDuration: 1.0, animations: {
                    self.storyImage.alpha = 1.0
                })
            }
            
            storySuperClearBackCircle.backgroundColor = .white
            storySuperClearBackCircle.alpha = 1.0
            storySuperClearBackCircle.layer.cornerRadius = storySuperClearBackCircle.frame.width / 2
            storySuperClearBackCircle.layer.masksToBounds = true
        } else {
            UIView.animate(withDuration: 1.0, animations: {
                self.storyImage.alpha = 0.9
            })
            //storyAuthorNameLabel.textColor = .black
            storyBackCircle.backgroundColor = .white
            storyWhiteBackCircle.backgroundColor = .white
            storySuperClearBackCircle.backgroundColor = .white
            pinSymbolView.isHidden = true
        }
        
        let sId = String(storyId)
        DispatchQueue.onceTechService(token: sId) {
            UIView.animate(withDuration: 0.7, animations: {
                self.preloadIndicator.alpha = 1
            })
            preloadIndicator.startAnimating()

            let preffixStart = Double(Int.random(in: 3..<5))
            let preffixEnd = Double(Int.random(in: 8..<11))
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(Double.random(in: preffixStart..<preffixEnd))) {
                UIView.animate(withDuration: 2.5, animations: {
                    self.preloadIndicator.alpha = 0
                    let bgColor = UIColor(red: 214/255, green: 214/255, blue: 214/255, alpha: 214/255)
                    self.storyBackCircle.backgroundColor = bgColor
                })
            }
        }
    }
    
    private func setImage(imagePathSdk: String) {
        guard let url = URL(string: imagePathSdk) else {
            return
        }
        
        self.storyImage.load.request(with: url)
    }
    
    private func makeConstraints() {
        
        storyBackCircle.topAnchor.constraint(equalTo: topAnchor).isActive = true
        storyBackCircle.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        storyBackCircle.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        storyBackCircle.heightAnchor.constraint(equalTo: storyBackCircle.widthAnchor).isActive = true
        
        storyWhiteBackCircle.topAnchor.constraint(equalTo: storyBackCircle.topAnchor, constant: 0).isActive = true
        storyWhiteBackCircle.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant: 0).isActive = true
        storyWhiteBackCircle.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: 0).isActive = true
        storyWhiteBackCircle.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: 0).isActive = true
        
        storySuperClearBackCircle.topAnchor.constraint(equalTo: storyBackCircle.topAnchor, constant: 2.3).isActive = true
        storySuperClearBackCircle.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant:2.3).isActive = true
        storySuperClearBackCircle.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: -2.3).isActive = true
        storySuperClearBackCircle.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: -2.3).isActive = true
        
        preloadIndicator.topAnchor.constraint(equalTo: storyBackCircle.topAnchor, constant: 0).isActive = true
        preloadIndicator.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant: 0).isActive = true
        preloadIndicator.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: 0).isActive = true
        preloadIndicator.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: 0).isActive = true
        preloadIndicator.heightAnchor.constraint(equalTo: storyBackCircle.widthAnchor).isActive = true
        preloadIndicator.heightAnchor.constraint(equalTo: storyBackCircle.widthAnchor).isActive = true
        
        storyImage.topAnchor.constraint(equalTo: storyWhiteBackCircle.topAnchor, constant: 4.2).isActive = true
        storyImage.leadingAnchor.constraint(equalTo: storyWhiteBackCircle.leadingAnchor, constant: 4.2).isActive = true
        storyImage.trailingAnchor.constraint(equalTo: storyWhiteBackCircle.trailingAnchor, constant: -4.2).isActive = true
        storyImage.bottomAnchor.constraint(equalTo: storyWhiteBackCircle.bottomAnchor, constant: -4.2).isActive = true
        
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
    
    func applyCustomColorScheme(_ colorScheme: SdkStyleCustomColorScheme) {
        //
    }
    
    func applySdkCustomFonts(_ fonts: SdkStyleCustomFonts) {
        //
    }
    
    public func showSdkPreloadIndicator() {
        preloadIndicator.startAnimating()
    }
    
    public func hideSdkPreloadIndicator() {
        preloadIndicator.stopAnimating()
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
