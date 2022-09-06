//
//  StoriesCollectionViewCell.swift
//  FirebaseCore
//
//  Created by Arseniy Dorogin on 16.08.2022.
//

import UIKit

class StoriesCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet private weak var storyImage: UIImageView!
    @IBOutlet private weak var storyBackCircle: UIView!
    @IBOutlet private weak var storyWhiteBackCircle: UIView!
    @IBOutlet private weak var storyAuthorNameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        storyBackCircle.backgroundColor = UIColor(red: 86/255, green: 178/255, blue: 114/255, alpha: 1)
    }

    public func configure(story: Story) {
        setImage(imagePath: story.avatar)
        storyAuthorNameLabel.text = "\(story.name)"
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        storyBackCircle.layer.cornerRadius = storyBackCircle.frame.width/2
        storyImage.layer.cornerRadius = storyImage.frame.width/2
        storyWhiteBackCircle.layer.cornerRadius = storyWhiteBackCircle.frame.width/2
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
                    self.storyImage.image = image
                }
            }
        })
        task.resume()
    }
}

