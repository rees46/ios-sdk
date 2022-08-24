//
//  StoryCollectionViewCell.swift
//  FirebaseCore
//
//  Created by Arseniy Dorogin on 17.08.2022.
//

import UIKit
import AVKit

class StoryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet private weak var videoView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var button: UIButton!
    
    private var selectedElement: StoryElement?

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = .black
        videoView.backgroundColor = .black
    }
    
    public func configure(slide: StorySlide) {
        if slide.type == "video" {
            videoView.isHidden = false
            imageView.isHidden = true
            self.videoView.layer.sublayers?.forEach {
                if $0.name == "VIDEO" {
                    $0.removeFromSuperlayer()
                }
            }

            let videoURL = URL(string: slide.background)
            let player = AVPlayer(url: videoURL!)
            player.volume = 1
            let playerLayer = AVPlayerLayer(player: player)
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
            button.layer.cornerRadius = 10
            button.setTitleColor(.blue, for: .normal)
            button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
            button.isHidden = false
        } else {
            button.isHidden = true
        }
    }
    
    @objc
    private func didTapButton() {
        if let link = selectedElement?.link {
            if let url = URL(string: link) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url)
                } else {
                    // Fallback on earlier versions
                }
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
