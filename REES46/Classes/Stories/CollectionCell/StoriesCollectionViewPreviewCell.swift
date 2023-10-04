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
    let storiesBlockAnimatedLoader = StoriesSlideReloadIndicator()
    
    private var task: URLSessionDataTask?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let bgColor = UIColor(red: 214/255, green: 214/255, blue: 214/255, alpha: 0.8)
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
        
        storiesBlockAnimatedLoader.contentMode = .scaleToFill
        storiesBlockAnimatedLoader.translatesAutoresizingMaskIntoConstraints = false
        storiesBlockAnimatedLoader.lineWidth = SdkConfiguration.stories.iconBorderWidth + 1.6 //3.9
        storiesBlockAnimatedLoader.numSegments = Int(Double(Int.random(in: 9..<17)))
        storiesBlockAnimatedLoader.animationDuration = Double(Int.random(in: 2..<3))
        storiesBlockAnimatedLoader.rotationDuration = 7
        storiesBlockAnimatedLoader.alpha = 0
        storyWhiteBackCircle.addSubview(storiesBlockAnimatedLoader)
        
        storyAuthorNameLabel.textAlignment = .center
        storyAuthorNameLabel.numberOfLines = SdkConfiguration.stories.storiesBlockNumberOfLines
        if SdkConfiguration.stories.storiesBlockCharWrapping {
            storyAuthorNameLabel.lineBreakMode = .byTruncatingTail
        } else {
            storyAuthorNameLabel.lineBreakMode = .byWordWrapping //.byTruncatingTail
            //storyAuthorNameLabel.allowsDefaultTighteningForTruncation = false
        }
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

        makeStoiesBlockCollectionConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        task?.cancel()
    }
    
    private func setImage(imagePathSdk: String) {
        guard let url = URL(string: imagePathSdk) else {
            return
        }
        
        self.storyImage.load.request(with: url)
    }
    
    public func configure(story: Story) {
        setImage(imagePathSdk: story.avatar)
        if SdkConfiguration.stories.storiesBlockCharWrapping {
            storyAuthorNameLabel.text = "\(story.name)".truncWords(length: SdkConfiguration.stories.storiesBlockCharCountWrap)
        } else {
            storyAuthorNameLabel.text = "\(story.name)"
        }
        pinSymbolView.isHidden = !story.pinned
    }
    
    func configureCell(settings: StoriesSettings?, viewed: Bool, viewedLocalKey: Bool, storyId: Int) {
        storyWhiteBackCircle.isHidden = false
        storySuperClearBackCircle.isHidden = false
        layoutIfNeeded()
        
        if let settings = settings {
            storyAuthorNameLabel.font = SdkStyle.shared.currentColorScheme?.storiesBlockSelectFontName.withSize(SdkStyle.shared.currentColorScheme!.storiesBlockSelectFontSize)
            let labelColor = settings.color.hexToRGB()
//            storyAuthorNameLabel.font = .systemFont(ofSize: CGFloat(settings.fontSize))
//            storyAuthorNameLabel.textColor = UIColor(red: labelColor.red, green: labelColor.green, blue: labelColor.blue, alpha: 1)
            
            storiesBlockAnimatedLoader.strokeColor = .white
            storyAuthorNameLabel.backgroundColor = .clear
            
            if (SdkStyle.shared.currentColorScheme?.storiesBlockFontColor == UIColor.sdkDefaultBlackColor) {
                storyAuthorNameLabel.textColor = UIColor(red: labelColor.red, green: labelColor.green, blue: labelColor.blue, alpha: 1)
            } else {
                if #available(iOS 12.0, *) {
                    if SdkConfiguration.isDarkMode {
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
                } else {
                    storyAuthorNameLabel.font = SdkStyle.shared.currentColorScheme?.storiesBlockSelectFontName
                }
            } else {
                if SdkConfiguration.stories.storiesBlockMinimumFontSizeChanged != 0.0 {
                    let size = SdkStyle.shared.currentColorScheme?.storiesBlockSelectFontSize ?? 15.0
                    storyAuthorNameLabel.font = .systemFont(ofSize: CGFloat(size))
                } else {
                    //storyAuthorNameLabel.maximumFontSizeBySdk = CGFloat(settings.fontSize)
                    storyAuthorNameLabel.font = .systemFont(ofSize: CGFloat(settings.fontSize))
                }
            }
            
            storyBackCircle.backgroundColor = .white
            let pinBgColor = settings.backgroundPin.hexToRGB()
            if SdkConfiguration.stories.pinColor != "" {
                var updPinColor = SdkConfiguration.stories.pinColor.hexToRGB()
                if #available(iOS 12.0, *) {
                    if SdkConfiguration.isDarkMode {
                        updPinColor = SdkConfiguration.stories.pinColorDarkMode.hexToRGB()
                    }
                }
                pinSymbolView.backgroundColor = UIColor(red: updPinColor.red, green: updPinColor.green, blue: updPinColor.blue, alpha: 1)
            } else {
                pinSymbolView.backgroundColor = UIColor(red: pinBgColor.red, green: pinBgColor.green, blue: pinBgColor.blue, alpha: 1)
            }
            pinSymbolLabel.text = settings.pinSymbol
            
            let storiesViewdBg = settings.borderViewed.hexToRGB()
            let storiesNotViewBg = settings.borderNotViewed.hexToRGB()
            
            if (viewed) {
                if SdkConfiguration.stories.iconViewedBorderColor == "" {
                    storyWhiteBackCircle.backgroundColor = viewed ?
                    UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1) :
                    UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1)
                    
                    storiesBlockAnimatedLoader.strokeColor = viewed ?
                    //UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1) :
                    //UIColor(red: storiesNotViewBg.red, green: storiesNotViewBg.green, blue: storiesNotViewBg.blue, alpha: 1)
                    UIColor(red: 255/255, green: 118/255, blue: 0/255, alpha: 1) :
                    UIColor(red: 255/255, green: 118/255, blue: 0/255, alpha: 1)
                } else {
                    var updViewedColor = SdkConfiguration.stories.iconViewedBorderColor.hexToRGB()
                    let animatedLoaderColor = SdkConfiguration.stories.iconAnimatedLoaderColor.hexToRGB()
                    if #available(iOS 12.0, *) {
                        if SdkConfiguration.isDarkMode {
                            updViewedColor = SdkConfiguration.stories.iconViewedBorderColorDarkMode.hexToRGB()
                        }
                    }
                    storyWhiteBackCircle.backgroundColor = UIColor(red: updViewedColor.red, green: updViewedColor.green, blue: updViewedColor.blue, alpha: 1)
                    
                    storiesBlockAnimatedLoader.strokeColor = UIColor(red: animatedLoaderColor.red, green: animatedLoaderColor.green, blue: animatedLoaderColor.blue, alpha: 1)
                }
            } else {
                if SdkConfiguration.stories.iconNotViewedBorderColor == "" {
                    storyWhiteBackCircle.backgroundColor = viewedLocalKey ?
                    UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1) :
                    UIColor(red: storiesNotViewBg.red, green: storiesNotViewBg.green, blue: storiesNotViewBg.blue, alpha: 1)
                    
                    storiesBlockAnimatedLoader.strokeColor = UIColor(red: storiesViewdBg.red, green: storiesViewdBg.green, blue: storiesViewdBg.blue, alpha: 1)
                } else {
                    var updNotViewedColor = SdkConfiguration.stories.iconNotViewedBorderColor.hexToRGB()
                    let animatedLoaderColor = SdkConfiguration.stories.iconAnimatedLoaderColor.hexToRGB()
                    if #available(iOS 12.0, *) {
                        if SdkConfiguration.isDarkMode {
                            updNotViewedColor = SdkConfiguration.stories.iconNotViewedBorderColorDarkMode.hexToRGB()
                        }
                    }
                    storyWhiteBackCircle.backgroundColor = UIColor(red: updNotViewedColor.red, green: updNotViewedColor.green, blue: updNotViewedColor.blue, alpha: 1)
                    
                    storiesBlockAnimatedLoader.strokeColor = UIColor(red: animatedLoaderColor.red, green: animatedLoaderColor.green, blue: animatedLoaderColor.blue, alpha: 1)
                }
            }
            storyWhiteBackCircle.layer.masksToBounds = true
            if storyImage.image == nil {
                if SdkConfiguration.stories.iconDisplayFormatSquare {
                    //Square implementation not needed corner
                } else {
                    storyWhiteBackCircle.layer.cornerRadius = storyWhiteBackCircle.frame.width / 2
                }
            }
            
            if SdkConfiguration.stories.iconViewedTransparency != SdkConfiguration.stories.defaultIconViewedTransparency {
                UIView.animate(withDuration: 1.0, animations: {
                    self.storyImage.alpha = SdkConfiguration.stories.iconViewedTransparency
                })
            } else {
                if (viewed || viewedLocalKey) {
                    UIView.animate(withDuration: 1.0, animations: {
                        self.storyImage.alpha = 0.9
                    })
                } else {
                    UIView.animate(withDuration: 1.0, animations: {
                        self.storyImage.alpha = 1.0
                    })
                }
            }
            
            storySuperClearBackCircle.backgroundColor = .white
            storySuperClearBackCircle.alpha = 1.0
            storySuperClearBackCircle.layer.masksToBounds = true
            if SdkConfiguration.stories.iconDisplayFormatSquare {
                //Square implementation coming soon
            } else {
                storySuperClearBackCircle.layer.cornerRadius = storySuperClearBackCircle.frame.width / 2
            }
        } else {
            UIView.animate(withDuration: 1.0, animations: {
                self.storyImage.alpha = 0.9
            })
            storyBackCircle.backgroundColor = .white
            storyWhiteBackCircle.backgroundColor = .white
            storySuperClearBackCircle.backgroundColor = .white
            pinSymbolView.isHidden = true
        }
        
        let sId = String(storyId)
        DispatchQueue.onceTechService(token: sId) {
            UIView.animate(withDuration: 0.7, animations: {
                self.storiesBlockAnimatedLoader.alpha = 1
            })
            storiesBlockAnimatedLoader.startAnimating()

            let preffixStart = Double(Int.random(in: 3..<5))
            let preffixEnd = Double(Int.random(in: 8..<11))
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(Double.random(in: preffixStart..<preffixEnd))) {
                UIView.animate(withDuration: 2.5, animations: {
                    self.storiesBlockAnimatedLoader.alpha = 0
                    let bgColor = UIColor(red: 214/255, green: 214/255, blue: 214/255, alpha: 214/255)
                    self.storyBackCircle.backgroundColor = bgColor
                })
            }
        }
    }
    
    private func makeStoiesBlockCollectionConstraints() {
        
        storyBackCircle.topAnchor.constraint(equalTo: topAnchor).isActive = true
        storyBackCircle.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        storyBackCircle.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        storyBackCircle.heightAnchor.constraint(equalTo: storyBackCircle.widthAnchor).isActive = true
        
        storyWhiteBackCircle.topAnchor.constraint(equalTo: storyBackCircle.topAnchor, constant: 0).isActive = true
        storyWhiteBackCircle.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant: 0).isActive = true
        storyWhiteBackCircle.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: 0).isActive = true
        storyWhiteBackCircle.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: 0).isActive = true
        
        storySuperClearBackCircle.topAnchor.constraint(equalTo: storyBackCircle.topAnchor, constant: SdkConfiguration.stories.iconBorderWidth).isActive = true
        storySuperClearBackCircle.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant:SdkConfiguration.stories.iconBorderWidth).isActive = true
        storySuperClearBackCircle.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: -SdkConfiguration.stories.iconBorderWidth).isActive = true
        storySuperClearBackCircle.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: -SdkConfiguration.stories.iconBorderWidth).isActive = true
        
        storiesBlockAnimatedLoader.topAnchor.constraint(equalTo: storyBackCircle.topAnchor, constant: 0).isActive = true
        storiesBlockAnimatedLoader.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant: 0).isActive = true
        storiesBlockAnimatedLoader.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: 0).isActive = true
        storiesBlockAnimatedLoader.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: 0).isActive = true
        storiesBlockAnimatedLoader.widthAnchor.constraint(equalTo: storyBackCircle.widthAnchor).isActive = true
        storiesBlockAnimatedLoader.heightAnchor.constraint(equalTo: storyBackCircle.heightAnchor).isActive = true
        
        storyImage.topAnchor.constraint(equalTo: storyWhiteBackCircle.topAnchor, constant: 4.2).isActive = true
        storyImage.leadingAnchor.constraint(equalTo: storyWhiteBackCircle.leadingAnchor, constant: 4.2).isActive = true
        storyImage.trailingAnchor.constraint(equalTo: storyWhiteBackCircle.trailingAnchor, constant: -4.2).isActive = true
        storyImage.bottomAnchor.constraint(equalTo: storyWhiteBackCircle.bottomAnchor, constant: -4.2).isActive = true
        
        storyAuthorNameLabel.topAnchor.constraint(equalTo: storyBackCircle.bottomAnchor, constant: SdkConfiguration.stories.iconMarginBottom).isActive = true
        
        if (SdkConfiguration.stories.labelWidth > SdkConfiguration.stories.iconSize) {
            let delta = (SdkConfiguration.stories.labelWidth / 2) + 10
            storyAuthorNameLabel.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant: -delta).isActive = true
            storyAuthorNameLabel.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: delta).isActive = true
        } else {
            storyAuthorNameLabel.leadingAnchor.constraint(equalTo: storyBackCircle.leadingAnchor, constant: -10).isActive = true
            storyAuthorNameLabel.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: 10).isActive = true
        }
        
        pinSymbolView.bottomAnchor.constraint(equalTo: storyBackCircle.bottomAnchor).isActive = true
        if SdkConfiguration.stories.iconDisplayFormatSquare {
            pinSymbolView.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: 0).isActive = true
        } else {
            pinSymbolView.trailingAnchor.constraint(equalTo: storyBackCircle.trailingAnchor, constant: -4).isActive = true
        }
        pinSymbolView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        pinSymbolView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        
        pinSymbolLabel.centerXAnchor.constraint(equalTo: pinSymbolView.centerXAnchor).isActive = true
        pinSymbolLabel.centerYAnchor.constraint(equalTo: pinSymbolView.centerYAnchor).isActive = true
    }
    
    public func showSdkPreloadIndicator() {
        storiesBlockAnimatedLoader.startAnimating()
    }
    
    public func hideSdkPreloadIndicator() {
        storiesBlockAnimatedLoader.stopAnimating()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if SdkConfiguration.stories.iconDisplayFormatSquare {
            //Square implementation coming soon
        } else {
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
}


private extension UIColor {
   private var rgbHexAlpha: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
       var red = CGFloat.zero
       var green = CGFloat.zero
       var blue = CGFloat.zero
       var alpha = CGFloat.zero
    
       guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
           debugPrint("color could not be retrieved")
           return (1.0, 1.0, 1.0, 1.0)
       }
       return (red, green, blue, alpha)
   }

   static func == (lhs: UIColor, rhs: UIColor) -> Bool {
       return  lhs.rgbHexAlpha == rhs.rgbHexAlpha
   }
}


extension String {
    enum TruncationPosition {
        case head
        case middle
        case tail
    }
    
    public func truncWords(length: Int, trailing: String = "…") -> String {
        if (self.count <= length) {
          return self
        }
        var truncated = self.prefix(length)
        while truncated.last != " " {

              guard truncated.count > length else {
                break
              }
          truncated = truncated.dropLast()
        }
        return truncated + trailing
      }
}
