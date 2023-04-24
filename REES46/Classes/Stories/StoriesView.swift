import Foundation
import UIKit

public class StoriesView: UIView {
    
    let cellId = "StoriesCollectionViewPreviewCell"
    
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
    private var settings: StoriesSettings?
    private var sdk: PersonalizationSDK?
    private var mainVC: UIViewController?
    private var code: String = ""
    
    private var isInDownloadMode: Bool = true

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
        collectionView.register(StoriesCollectionViewPreviewCell.self, forCellWithReuseIdentifier: StoriesCollectionViewPreviewCell.cellId)
    }
    
    public func configure(sdk: PersonalizationSDK, mainVC: UIViewController, code: String) {
        self.sdk = sdk
        self.mainVC = mainVC
        self.code = code
        loadData()
    }
    
    private func setBgColor(color: String) {
        let hex = color.hexToRGB()
        DispatchQueue.main.async {
            self.collectionView.backgroundColor = UIColor(red: hex.red, green: hex.green, blue: hex.blue, alpha: 1)
        }
    }
    
    public func reloadData() {
        self.collectionView.reloadData()
    }

    private func loadData() {
        sdk?.getStories(code: code) { result in
            switch result {
            case let .success(response):
                self.stories = response.stories
                self.settings = response.settings
                self.setBgColor(color: response.settings.background)
                DispatchQueue.main.async {
                    self.isInDownloadMode = false
                    self.collectionView.reloadData()
                }
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
            }
        }
    }
}

extension StoriesView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isInDownloadMode ? 4 : stories?.count ?? 0
        
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StoriesCollectionViewPreviewCell.cellId, for: indexPath) as? StoriesCollectionViewPreviewCell else {return UICollectionViewCell()}
        if let currentStory = stories?[indexPath.row] {
            
            let storyId = String(currentStory.id)
            let storyName = "story." + storyId
            
            var allStoriesMainArray: [String] = []
            for (index, _) in currentStory.slides.enumerated() {
                print("Story has \(index + 1): \(currentStory.slides[(index)].id)")
                allStoriesMainArray.append(String(currentStory.slides[(index)].id))
            }
            
            let watchedStoriesArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
            //let watchedStoriesArray: [String] = defaults.stringArray(forKey: storyName) ?? []
            if (watchedStoriesArray.count == allStoriesMainArray.count) {
                cell.configureCell(settings: settings, viewed: currentStory.viewed, viewedLocalKey: true)
                cell.configure(story: currentStory)
            } else {
                cell.configureCell(settings: settings, viewed: currentStory.viewed, viewedLocalKey: false)
                cell.configure(story: currentStory)
            }
        }
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let currentStory = stories?[indexPath.row] {
            let storyVC = StoryViewController()
            storyVC.sdk = sdk
            storyVC.stories = stories ?? []
            
            let sId = "story." + String(currentStory.id)
            
            var allStoriesMainArray: [String] = []
            for (index, _) in currentStory.slides.enumerated() {
                allStoriesMainArray.append(String(currentStory.slides[(index)].id))
            }
            
            let watchedStoriesArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(sId)) as? [String] ?? []
            let lastWatchedIndexValue = watchedStoriesArray.last
            
            var currentDefaultIndex = 0
            for name in allStoriesMainArray {
                if name == lastWatchedIndexValue {
                    //print("Story \(name) for index \(currentDefaultIndex)")
                    break
                }
                currentDefaultIndex += 1
            }
            
            if (currentDefaultIndex + 1 < allStoriesMainArray.count) {
                storyVC.currentPosition = IndexPath(row: Int(currentDefaultIndex + 1), section: indexPath.row)
                storyVC.startWithIndexPath = IndexPath(row: Int(currentDefaultIndex + 1), section: indexPath.row)
                storyVC.modalPresentationStyle = .fullScreen
                mainVC?.present(storyVC, animated: true)
            } else if (currentDefaultIndex + 1 == allStoriesMainArray.count) {
                storyVC.currentPosition = IndexPath(row: Int(0), section: indexPath.row)
                storyVC.startWithIndexPath = IndexPath(row: Int(0), section: indexPath.row)
                storyVC.modalPresentationStyle = .fullScreen
                mainVC?.present(storyVC, animated: true)
            } else {
                storyVC.currentPosition = IndexPath(row: currentStory.startPosition, section: indexPath.row)
                storyVC.startWithIndexPath = IndexPath(row: currentStory.startPosition, section: indexPath.row)
                storyVC.modalPresentationStyle = .fullScreen
                mainVC?.present(storyVC, animated: true)
            }
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
