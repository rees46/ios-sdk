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
    
    private let vDownloadManager = VideoDownloadManager.shared
    var sdkDirectoryName : String = "SDKCacheDirectory"
    
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
                print("SDK Success video preview for \(self.id) is downloaded")
            }
            
            downloadVideo { result in
                switch result {
                case .success(let url):
                    self.videoURL = url
                    self.completionCached(slideWithId: self.id, workingSlideUrl: url)
                case .failure(let error):
                    print("SDK Video for \(self.id) is not downloaded with error \(error.localizedDescription)")
                }
            }
        } else if type == .image {
            setImage(imageURL: self.background, isPreview: false)
        }
    }
 
    func downloadVideo(completion: @escaping (Result<URL, Error>) -> Void) {
        
        guard let url = URL(string: self.background) else {
            completion(.failure(NSError(domain: "SDK Invalid URL", code: -1, userInfo: nil)))
            return
        }
        
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent("\(self.id).mp4")
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: temporaryFileURL.path) {
            completion(.success(temporaryFileURL))
            print("SDK Load cached video for story id = \(self.id)")
            return
        }
        
        let request = URLRequest(url: url)
        _ = self.vDownloadManager.downloadStoryMediaFile(withRequest: request,
                                                        inDirectory: sdkDirectoryName,
                                                        shouldDownloadInBackground: true,
                                                        //shouldDownloadInBackground: false,
                                                        onProgress: {(progress) in
            
        }) {(error, url) in
            if let error = error {
                print("Error is \(error as NSError)")
            } else {
                if let url = url {
                    do {
                        try fileManager.moveItem(at: url, to: temporaryFileURL)
                        //print("SDK Downloaded video for story id = \(self.id)")
                        completion(.success(temporaryFileURL))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    func getVideoData(from fileURL: URL) -> Data? {
        do {
            let videoData = try Data(contentsOf: fileURL)
            return videoData
        } catch {
            print("SDK Error reading video data: \(error)")
            return nil
        }
    }
    
    private func setImage(imageURL: String, isPreview: Bool) {
        guard let url = URL(string: imageURL) else {
            return
        }
        
        StoryCellImageCache.image(for: url.absoluteString) { cachedImage in
            
            if isPreview {
                self.previewImage = cachedImage
                //print("Downloaded preview for image for video story with id = \(self.id)")
            } else {
                self.downloadedImage = cachedImage
            }
            
            if cachedImage != nil {
                self.completionCached(slideWithId: self.id, workingSlideUrl: url)
                print("SDK Load cached image for story id = \(self.id)")
                
            } else {
                let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
                    if error == nil {
                        
                        guard let unwrappedData = data, let image = UIImage(data: unwrappedData) else { return }
                        if isPreview {
                            self.previewImage = image
                        } else {
                            self.downloadedImage = image
                            
                            StoryCellImageCache.save(image, for: url.absoluteString)
                            self.completionCached(slideWithId: self.id, workingSlideUrl: url)
                            //print("SDK Downloaded image for story id = \(self.id)")
                        }
                    }
                })
                task.resume()
            }
        }
    }
    
    private func completionCached(slideWithId: Int, workingSlideUrl: URL) {
        let storyImageId = String(slideWithId)
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
        let userInfo = ["url": workingSlideUrl] as [String: Any]
        NotificationCenter.default.post(name:Notification.Name(name), object: userInfo)
    }
}


// MARK: - Element
public class StoriesElement {
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
public class StoriesProduct {
    let name: String
    let currency: String
    let price: Int
    let price_full: Int
    let price_formatted, price_full_formatted: String
    let oldprice: Int?
    let oldprice_full: Int
    let oldprice_formatted, oldprice_full_formatted: String
    let url: String
    let picture: String
    let discount: String?
    let discount_formatted: String?
    let category: StoriesCategory
    
    public init(json: [String:Any]) {
        self.name = json["name"] as? String ?? ""
        self.currency = json["currency"] as? String ?? ""
        self.price = json["price"] as? Int ?? 0
        self.price_full = json["price_full"] as? Int ?? 0
        self.price_formatted = json["price_formatted"] as? String ?? ""
        self.price_full_formatted = json["price_full_formatted"] as? String ?? ""
        self.oldprice = json["oldprice"] as? Int ?? 0
        self.oldprice_full = json["oldprice_full"] as? Int ?? 0
        self.oldprice_formatted = json["oldprice_formatted"] as? String ?? ""
        self.oldprice_full_formatted = json["oldprice_full_formatted"] as? String ?? ""
        self.url = json["url"] as? String ?? ""
        self.picture = json["picture"] as? String ?? ""
        self.discount = json["discount"] as? String ?? ""
        self.discount_formatted = json["discount_formatted"] as? String ?? "0%"
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
