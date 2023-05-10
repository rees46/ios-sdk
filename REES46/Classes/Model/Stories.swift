import Foundation
import UIKit

public class StoryContent {
    let id: Int
    let settings: StoriesSettings
    let stories: [Story]
    
    public init(json: [String: Any]) {
        self.id = json["id"] as? Int ?? -1
        let _settings = json["settings"] as? [String: Any] ?? [:]
        self.settings = StoriesSettings(json: _settings)
        let _stories = json["stories"] as? [[String: Any]] ?? []
        self.stories = _stories.map({Story(json: $0)})
    }
}

// MARK: - Settings
public class StoriesSettings {
    let color: String
    let fontSize: Int
    let background: String
    let avatarSize: Int
    let closeColor: String
    let borderViewed, backgroundPin, borderNotViewed: String
    let backgroundOpacity: Int
    let backgroundProgress: String
    let pinSymbol: String

    public init(json: [String: Any]) {
        self.color = json["color"] as? String ?? ""
        self.fontSize = json["font_size"] as? Int ?? 12
        self.background = json["background"] as? String ?? ""
        self.avatarSize = json["avatar_size"] as? Int ?? 20
        self.closeColor = json["close_color"] as? String ?? ""
        self.borderViewed = json["border_viewed"] as? String ?? ""
        self.backgroundPin = json["background_pin"] as? String ?? ""
        self.borderNotViewed = json["border_not_viewed"] as? String ?? ""
        self.backgroundOpacity = json["background_opacity"] as? Int ?? 100
        self.backgroundProgress = json["background_progress"] as? String ?? ""
        self.pinSymbol = json["pin_symbol"] as? String ?? ""
    }
}


// MARK: - Story
class Story {
    let id: Int
    let avatar: String
    let viewed: Bool
    let startPosition: Int
    let name: String
    let pinned: Bool
    let slides: [Slide]
    
    public init(json: [String: Any]) {
        self.id = json["id"] as? Int ?? -1
        self.avatar = json["avatar"] as? String ?? ""
        self.viewed = json["viewed"] as? Bool ?? false
        self.startPosition = json["start_position"] as? Int ?? 0
        self.name = json["name"] as? String ?? ""
        self.pinned = json["pinned"] as? Bool ?? false
        let _slides = json["slides"] as? [[String: Any]] ?? []
        self.slides = _slides.map({Slide(json: $0)})
        
    }
}

// MARK: - Slide
class Slide {
    let id, duration: Int
    let background: String
    let preview: String?
    let type: SlideType
    let elements: [StoriesElement]
    var videoURL: URL? = nil
    var downloadedImage: UIImage? = nil
    var previewImage: UIImage? = nil
    
    private let downloadManager = RRDownloadManager.shared
    var directoryName : String = "CacheDirectory"
    
    public init(json: [String: Any]) {
        self.id = json["id"] as? Int ?? -1
        self.duration = json["duration"] as? Int ?? 10
        self.background = json["background"] as? String ?? ""
        self.preview = json["preview"] as? String
        let _type = json["type"] as? String ?? ""
        self.type = SlideType(rawValue: _type) ?? .unknown
        let _elements = json["elements"] as? [[String: Any]] ?? []
        self.elements = _elements.map({StoriesElement(json: $0)})
        
        if type == .video {
            if preview != nil {
                setImage(imageURL: preview!, isPreview: true)
            } else {
                print("Success setImage video for \(self.id) is downloaded")
            }
            
            downloadVideo { result in
                switch result {
                case .success(let url):
                    self.videoURL = url
                    print("Downloaded video for story id = \(self.id)")
                    
                    let storyImageId = String(self.id)
                    let storyImageDownloadedName = "waitStorySlideCached." + storyImageId
                    
                    var watchedStoriesDownloadedArr: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyImageDownloadedName)) as? [String] ?? []
                    let watchedStoryIdExists = watchedStoriesDownloadedArr.contains(where: {
                        $0.range(of: String(storyImageDownloadedName)) != nil
                    })
                    
                    if !watchedStoryIdExists {
                        watchedStoriesDownloadedArr.append(storyImageDownloadedName)
                        UserDefaults.standard.setValue(watchedStoriesDownloadedArr, for: UserDefaults.Key(storyImageDownloadedName))
                    }
                    
                    let name = "waitStorySlideCached." + storyImageId
                    let userInfo = ["url": url] as [String: Any]
                    NotificationCenter.default.post(name:Notification.Name(name), object: userInfo)
                    
                case .failure(let error):
                    print("Video for \(self.id) is not downloaded with error \(error.localizedDescription)")
                }
            }
        } else if type == .image {
            setImage(imageURL: self.background, isPreview: false)
        }
    }
 
    func downloadVideo(completion: @escaping (Result<URL, Error>) -> Void) {
        
        guard let url = URL(string: self.background) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent("\(self.id).mp4")
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: temporaryFileURL.path) {
            completion(.success(temporaryFileURL))
            return
        }
        
        let request = URLRequest(url: url)
        
        let downloadKey = self.downloadManager.downloadFile(withRequest: request,
                                                           inDirectory: directoryName,
                                                           onProgress:  { [weak self] (progress) in
                                                            //let percentage = String(format: "%.1f %", (progress * 100))
                                                            //self?.progressView.setProgress(Float(progress), animated: true)
                                                            //self?.progressLabel.text = "\(percentage) %"
            
            let percentageD = String(format: "%.1f %", (progress * 100))
            //debugPrint("Background download video progress : \(percentageD) for task \(request.debugDescription)")
        }) { [weak self] (error, url) in
            
            if let error = error {
                print("Error is \(error as NSError)")
            } else {
                if let url = url {
                    //print("Downloaded file's url is \(url.path)")
                    do {
                        try fileManager.moveItem(at: url, to: temporaryFileURL)
                        completion(.success(temporaryFileURL))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
        //print("The video with key is downloaded \(downloadKey!)")
        

//        // Checking if a file exists
//        if fileManager.fileExists(atPath: temporaryFileURL.path) {
//            completion(.success(temporaryFileURL))
//            return
//        }
//
//        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
//            guard let location = location else {
//                completion(.failure(error ?? NSError(domain: "Unknown error", code: -1, userInfo: nil)))
//                return
//            }
//
//            do {
//                try fileManager.moveItem(at: location, to: temporaryFileURL)
//                completion(.success(temporaryFileURL))
//            } catch {
//                completion(.failure(error))
//            }
//        }
//
//        task.resume()
    }

    
    func getVideoData(from fileURL: URL) -> Data? {
        do {
            let videoData = try Data(contentsOf: fileURL)
            return videoData
        } catch {
            print("Error reading video data: \(error)")
            return nil
        }
    }
    
    private func setImage(imageURL: String, isPreview: Bool) {
        guard let url = URL(string: imageURL) else {
            return
        }
        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
            if error == nil {
                guard let unwrappedData = data, let image = UIImage(data: unwrappedData) else { return }
                if isPreview {
                    self.previewImage = image
                    //print("Downloaded preview for image for VIDEO story with id = \(self.id)")
                } else {
                    self.downloadedImage = image
                    print("Downloaded image for story id = \(self.id)")
                    
                    let storyImageId = String(self.id)
                    let storyImageDownloadedName = "waitStorySlideCached." + storyImageId
                    var watchedStoriesDownloadedArr: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyImageDownloadedName)) as? [String] ?? []
                    let watchedStoryIdExists = watchedStoriesDownloadedArr.contains(where: {
                        $0.range(of: String(storyImageDownloadedName)) != nil
                    })
                    
                    if !watchedStoryIdExists {
                        watchedStoriesDownloadedArr.append(storyImageDownloadedName)
                        UserDefaults.standard.setValue(watchedStoriesDownloadedArr, for: UserDefaults.Key(storyImageDownloadedName))
                    }
                    
                    let name = "waitStorySlideCached." + storyImageId
                    let userInfo = ["url": url] as [String: Any]
                    NotificationCenter.default.post(name:Notification.Name(name), object: userInfo)
                }
            }
        })
        task.resume()
    }
}

// MARK: - Element
class StoriesElement {
    let link: String?
    let type: ElementType
    let color: String?
    let title, linkIos: String?
    let textBold: Bool?
    let background: String?
    let linkAndroid: String?
    let labels: Labels?
    let products: [StoriesProduct]?
    let cornerRadius: Int
    
    public init(json: [String: Any]) {
        self.link = json["link"] as? String
        let _type = json["type"] as? String ?? ""
        self.type = ElementType(rawValue: _type) ?? .unknown
        self.color = json["color"] as? String
        self.title = json["title"] as? String
        self.linkIos = json["link_ios"] as? String
        self.textBold = json["text_bold"] as? Bool
        self.background = json["background"] as? String
        self.linkAndroid = json["link_android"] as? String
        let _labels = json["labels"] as? [String: Any] ?? [:]
        self.labels = Labels(json: _labels)
        let _products = json["products"] as? [[String: Any]] ?? []
        self.products = _products.map({StoriesProduct(json: $0)})
        self.cornerRadius = json["corner_radius"] as? Int ?? 12
    }

}

// MARK: - Labels
class Labels {
    let hideCarousel, showCarousel: String
    
    public init(json: [String: Any]) {
        self.hideCarousel = json["hide_carousel"] as? String ?? ""
        self.showCarousel = json["show_carousel"] as? String ?? ""
    }
}

// MARK: - Product
class StoriesProduct {
    let name, price: String
    let oldprice: String?
    let url: String
    let picture: String
    let discount: String?
    let category: StoriesCategory
    
    public init(json: [String:Any]) {
        self.name = json["name"] as? String ?? ""
        self.price = json["price"] as? String ?? ""
        self.oldprice = json["oldprice"] as? String ?? ""
        self.url = json["url"] as? String ?? ""
        self.picture = json["picture"] as? String ?? ""
        self.discount = json["discount"] as? String ?? ""
        let _category = json["category"] as? [String: Any] ?? [:]
        self.category = StoriesCategory(json: _category)
    }
}

// MARK: - Category
class StoriesCategory {
    let name: String
    let url: String
    
    public init(json: [String: Any]) {
        self.name = json["name"] as? String ?? ""
        self.url = json["url"] as? String ?? ""
       }
}

enum ElementType: String {
    case button = "button"
    case products = "products"
    case unknown
}

enum SlideType: String {
    case image = "image"
    case video = "video"
    case unknown = ""
}
