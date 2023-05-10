import UIKit
import AVKit
import AVFoundation

protocol StoryCollectionViewCellDelegate: AnyObject {
    func didTapUrlButton(url: String, slide: Slide)
    func didTapOpenLinkIosExternalWeb(url: String, slide: Slide)
}

class StoryCollectionViewCell: UICollectionViewCell {
    
    static let cellId = "StoryCollectionViewCellId"
    
    let videoView = UIView()
    let imageView = UIImageView()
    let storyButton = StoryButton()
//    let muteButton = UIButton()
    
    private var selectedElement: StoriesElement?
    private var currentSlide: Slide?
    
    public weak var delegate: StoryCollectionViewCellDelegate?
    
    var player = AVPlayer()
    private let timeObserverKeyPath: String = "timeControlStatus"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .black
        videoView.backgroundColor = .black
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideo(_:)), name: .init(rawValue: "PauseVideoLongTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playVideo(_:)), name: .init(rawValue: "PlayVideoLongTap"), object: nil)
        
        player.addObserver(self, forKeyPath: timeObserverKeyPath, options: [.old, .new], context: nil)
        
        videoView.contentMode = .scaleToFill
        videoView.isOpaque = true
        videoView.clearsContextBeforeDrawing = true
        videoView.autoresizesSubviews = true
        videoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        storyButton.translatesAutoresizingMaskIntoConstraints = false
        storyButton.setTitle("Tap me", for: .normal)
        storyButton.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        
        addSubview(storyButton)
//        let bundle = Bundle(for: classForCoder)
//        muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: bundle, compatibleWith: nil), for: .normal)
//        muteButton.translatesAutoresizingMaskIntoConstraints = false
//        muteButton.isHidden = true
//        muteButton.addTarget(self, action: #selector(didTapOnMute), for: .touchUpInside)
//        addSubview(muteButton)
        
        makeConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeConstraints(){
        videoView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        videoView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        videoView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        videoView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        imageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        imageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        imageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
        storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
        storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -44).isActive = true
        storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
//        muteButton.topAnchor.constraint(equalTo: topAnchor, constant: 64).isActive = true
//        muteButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10).isActive = true
//        muteButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
//        muteButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
    }
    
//    @objc private func didTapOnMute() {
//        let bundle = Bundle(for: classForCoder)
//        if player.volume == 1.0 {
//            player.volume = 0.0
//            muteButton.setImage(UIImage(named: "iconStoryMute", in: bundle, compatibleWith: nil), for: .normal)
//        } else {
//            player.volume = 1.0
//            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: bundle, compatibleWith: nil), for: .normal)
//        }
//    }
    
    @objc
    private func pauseVideo(_ notification: NSNotification) {
        if let slideID = notification.userInfo?["slideID"] as? Int {
            if let currentSlide = currentSlide {
                if currentSlide.id == slideID {
                    player.pause()
                }
            }
        }
    }
    
    @objc
    private func playVideo(_ notification: NSNotification) {
        if let slideID = notification.userInfo?["slideID"] as? Int {
            if let currentSlide = currentSlide {
                if currentSlide.id == slideID {
                    player.play()
                }
            }
        }
    }
    
//    private func setButtonToDefault() {
//        let bundle = Bundle(for: classForCoder)
//        muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: bundle, compatibleWith: nil), for: .normal)
//    }
    
    public func configure(slide: Slide) {
//        setButtonToDefault()
        self.currentSlide = slide
        if slide.type == .video {
//            if let preview = slide.previewImage {
//                DispatchQueue.main.async {
//                    self.imageView.image = preview
//                    self.videoView.isHidden = true
//                    self.imageView.isHidden = false
//                }
//            }

            videoView.isHidden = false
            imageView.isHidden = true

            self.videoView.layer.sublayers?.forEach {
                if $0.name == "VIDEO" {
                    $0.removeFromSuperlayer()
                }
            }
            if let videoURL = slide.videoURL {
                //muteButton.isHidden = false
                videoView.isHidden = false
                imageView.isHidden = true

                let asset = AVAsset(url: videoURL)
//                let length = Float(asset.duration.value)/Float(asset.duration.timescale)
//                if length != 0.0  {
//                } else {
//                }
                
                let playerItem = AVPlayerItem(asset: asset)
                self.player = AVPlayer(playerItem: playerItem)
                let playerLayer = AVPlayerLayer(player: player)
                player.volume = 1
                let screenSize = UIScreen.main.bounds.size
                playerLayer.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
                playerLayer.name = "VIDEO"
                self.videoView.layer.addSublayer(playerLayer)
                player.play()
            } else {
                //muteButton.isHidden = true
                imageView.isHidden = false
                videoView.isHidden = true
                if let preview = slide.previewImage {
                    self.imageView.image = preview
                }
            }
        } else {
            //muteButton.isHidden = true
            imageView.isHidden = false
            videoView.isHidden = true
            if let image = slide.downloadedImage {
                self.imageView.image = image
            }
        }

        if let element = slide.elements.first(where: {$0.type == .button}) {
            selectedElement = element
            storyButton.configButton(buttonData: element)
            storyButton.isHidden = false
        } else {
            storyButton.isHidden = true
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

//        if keyPath == "timeControlStatus",
//           let change = change,
//           let newValue = change[NSKeyValueChangeKey.newKey] as? Int,
//           let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
//
//            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
//            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
//            print(oldStatus?.rawValue)
//            if newStatus != oldStatus {
//                if newStatus == .playing {
//                    player.seek(to: .zero)
//                    player.removeObserver(self, forKeyPath: timeObserverKeyPath)
//                    //delegate?.videoLoaded()
//                } else if newStatus == .waitingToPlayAtSpecifiedRate {
//                    player.seek(to: .zero)
//                    player.removeObserver(self, forKeyPath: timeObserverKeyPath)
//                    player.play()
//                }
//            }
//        }
        
//        if object as AnyObject? === videoView.snapVideo.currentItem && keyPath == "status" {
//            if videoView.status == .readyToPlay  && isViewInFocus && isCompletelyVisible {
//                videoView.play()
//                print("StoryCell: Ready to play video")
//            }
//        }
//
//        if object as AnyObject? === videoView.snapVideo && keyPath == "timeControlStatus" {
//            if videoView.snapVideo.timeControlStatus == .playing && isViewInFocus && isCompletelyVisible {
//                print("StoryCell : timeControlStatus == .playing")
//                var videoDuration: Double = 5
//                if let currentItem = videoView.snapVideo.currentItem {
//                    videoDuration = currentItem.duration.seconds
//                }
//                startAnimatingStory(duration: videoDuration)
//                print("StoryCell: Video started animating")
//            }
//        }
    }
    
    func stopPlayer() {
        player.pause()
    }

    
    @objc
    private func didTapButton() {
        
        if let linkIos = selectedElement?.linkIos, !linkIos.isEmpty {
            if let currentSlide = currentSlide {
                delegate?.didTapOpenLinkIosExternalWeb(url: linkIos, slide: currentSlide)
                print(linkIos, currentSlide)
                
                //delegate?.didTapUrlButton(url: linkIos, slide: currentSlide) //TEST
                //(UIApplication.shared.delegate as? StoryLinkDelegate)?.openlinkIosStoryWeb(url: linkIos)
                return
            }
        }
        
        if let link = selectedElement?.link, !link.isEmpty {
            if let currentSlide = currentSlide {
                delegate?.didTapUrlButton(url: link, slide: currentSlide)
                return
            }
        }
    }
    
    private func setImage(imagePath: String) {
        guard let url = URL(string: imagePath) else {
            return
        }

        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
            if error == nil {
                guard let unwrappedData = data, let image = UIImage(data: unwrappedData) else { return }
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }
        })
        task.resume()
    }

    private func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return UIColor.gray
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
}
