//
//  StoryCollectionViewCell.swift
//  FirebaseCore
//
//  Created by Arseniy Dorogin on 17.08.2022.
//

import UIKit
import AVKit

protocol StoryCollectionViewCellDelegate: AnyObject {
    func didTapUrlButton(url: String, slide: StorySlide)
}

class StoryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet private weak var videoView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var button: UIButton!
    
    private var selectedElement: StoryElement?
    private var currentSlide: StorySlide?
    
    public weak var delegate: StoryCollectionViewCellDelegate?
    
    var player = AVPlayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = .black
        videoView.backgroundColor = .black
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideo(_:)), name: .init(rawValue: "PauseVideoLongTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playVideo(_:)), name: .init(rawValue: "PlayVideoLongTap"), object: nil)
    }
    
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
    
    public func configure(slide: StorySlide) {
        self.currentSlide = slide
        if slide.type == "video" {
            videoView.isHidden = false
            imageView.isHidden = true
            self.videoView.layer.sublayers?.forEach {
                if $0.name == "VIDEO" {
                    $0.removeFromSuperlayer()
                }
            }

            let videoURL = URL(string: slide.background)
            self.player = AVPlayer(url: videoURL!)
            let playerLayer = AVPlayerLayer(player: player)
            player.volume = 1
            let screenSize = UIScreen.main.bounds.size
            playerLayer.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
            playerLayer.name = "VIDEO"
            print(slide.background)
            self.videoView.layer.addSublayer(playerLayer)
            player.play()
        } else {
            imageView.isHidden = false
            videoView.isHidden = true
            setImage(imagePath: slide.background)
        }
        if let element = slide.elements.first(where: {$0.type == "button"}) {
            selectedElement = element
            button.setTitle(element.title, for: .normal)
            button.backgroundColor = .white
            button.layer.cornerRadius = 13
            button.setTitleColor(.black, for: .normal)
            button.setTitleColor(.black, for: .selected)
            button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
            button.isHidden = false
        } else {
            button.isHidden = true
        }
    }
    
    @objc
    private func didTapButton() {
        if let link = selectedElement?.link {
            if let currentSlide = currentSlide {
                delegate?.didTapUrlButton(url: link, slide: currentSlide)
            }
        }
    }
    
    private func setImage(imagePath: String) {
        guard let url = URL(string: imagePath) else {
            print("Failed to present attachment due to an invalid url: ", imagePath)
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
