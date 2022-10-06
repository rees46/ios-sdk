//
//  StoriesView.swift
//  FirebaseCore
//
//  Created by Arseniy Dorogin on 16.08.2022.
//

import Foundation
import UIKit

public class StoriesView: UIView {
    
    private var collectionView: UICollectionView = {
        let testFrame = CGRect(x: 0, y: 0, width: 300, height: 113)
        let layout = UICollectionViewFlowLayout()
//        layout.horizontalAlignment = .left
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.scrollDirection = .horizontal
        
        layout.itemSize = CGSize(width: 76, height: 113)
        
        let collectionView = UICollectionView(frame: testFrame, collectionViewLayout: layout)
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()
    
    private var stories: [Story]?
    private var sdk: PersonalizationSDK?
    private var mainVC: UIViewController?
    private var code: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        self.addSubview(collectionView)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.left, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.left, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 0).isActive = true
        configureView()
    }

    private func configureView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        let bundle = Bundle(for: self.classForCoder)
        let nib = UINib(nibName: "StoriesCollectionViewCell", bundle: bundle)
        collectionView.register(nib, forCellWithReuseIdentifier: "StoriesCollectionViewCell")
    }
    
    public func configure(sdk: PersonalizationSDK, mainVC: UIViewController, code: String) {
        self.sdk = sdk
        self.mainVC = mainVC
        self.code = code
        loadData()
    }

    private func loadData() {
        sdk?.getStories(code: code) { result in
            switch result {
            case let .success(response):
                self.stories = response.stories
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            case let .failure(error):
                break
            }
        }
    }
}

extension StoriesView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        stories?.count ?? 0
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StoriesCollectionViewCell", for: indexPath) as! StoriesCollectionViewCell
        if let currentStory = stories?[indexPath.row] {
            cell.configure(story: currentStory)
        }
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let currentStory = stories?[indexPath.row] {
            let storyVC = StoryViewController()
            storyVC.sdk = sdk
            storyVC.stories = stories ?? []
            storyVC.currentPosition = IndexPath(row: currentStory.startPosition, section: indexPath.row)
            storyVC.startWithIndexPath = IndexPath(row: currentStory.startPosition, section: indexPath.row)
            storyVC.modalPresentationStyle = .fullScreen
            mainVC?.present(storyVC, animated: true)
        }
    }
}

extension UIView {
    func fixInView(_ container: UIView!) {
        translatesAutoresizingMaskIntoConstraints = false
        frame = container.frame
        container.addSubview(self)
        NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: container, attribute: .leading, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: container, attribute: .trailing, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: container, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: container, attribute: .bottom, multiplier: 1.0, constant: 0).isActive = true
    }
}
