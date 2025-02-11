import AVFoundation
import Foundation

class Slide: Codable {
  var id: String
  var duration: Int
  let background: String
  let backgroundColor: String
  let preview: String?
  let ids: Int
  let type: SlideType
  let elements: [StoriesElement]
  var videoURL: URL? = nil
  var downloadedImage: UIImage? = nil
  var previewImage: UIImage? = nil
  
  public let vDownloadManager = VideoDownloadManager.shared
  var sdkDirectoryName: String = "SDKCacheDirectory"
  private enum CodingKeys: String, CodingKey {
    case id, duration, background, preview, type, elements
    case backgroundColor = "background_color"
  }
  required public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    ids = try container.decode(Int.self, forKey: .id)
    if let ids = try container.decodeIfPresent(Int.self, forKey: .id) {
     id = String(ids)
   }
    duration = try container.decode(Int.self, forKey: .duration)
    background = try container.decode(String.self, forKey: .background)
    backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
    preview = try container.decodeIfPresent(String.self, forKey: .preview)
    type = SlideType(rawValue: try container.decode(String.self, forKey: .type)) ?? .unknown
    elements = try container.decode([StoriesElement].self, forKey: .elements)

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
          self.completionCached(slideWithId: self.id, actualSlideUrl: "")
        case .failure(let error):
          print("SDK Video for \(self.id) is not downloaded with error \(error.localizedDescription)")
        }
      }
      
    } else if type == .image {
      setImage(imageURL: self.background, isPreview: false)
    } else {
      self.completionCached(slideWithId: self.id, actualSlideUrl: "")
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
      //print("SDK Load cached video for story id = \(self.id)")
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
            
            let duration = AVURLAsset(url: temporaryFileURL).duration.seconds
            let vTime = String(format:"%d", Int(duration.truncatingRemainder(dividingBy: 60)))
            //print(vTime)
            
            DispatchQueue.main.async {
              SdkGlobalHelper.sharedInstance.saveVideoParamsToDictionary(parentSlideId: self.id, paramsDictionary: [self.id : vTime])
            }
            
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
    
    StoryBlockImageCache.image(for: url.absoluteString) { cachedImage in
      if isPreview {
        self.previewImage = cachedImage
        //print("Downloaded preview for image for video story with id = \(self.id)")
      } else {
        self.downloadedImage = cachedImage
      }
      
      if cachedImage != nil {
        self.completionCached(slideWithId: self.id, actualSlideUrl: "")
        //print("SDK Load cached image for story id = \(String(describing: self.id))")
      } else {
        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
          if error == nil {
            guard let unwrappedData = data, let image = UIImage(data: unwrappedData) else {
              return
            }
            if isPreview {
              self.previewImage = image
            } else {
              self.downloadedImage = image
              
              StoryBlockImageCache.save(image, for: url.absoluteString)
              self.completionCached(slideWithId: self.id, actualSlideUrl: "")
              //print("SDK Downloaded image for story id = \(self.id)")
            }
          }
        })
        task.resume()
      }
    }
  }
  
  private func completionCached(slideWithId: String, actualSlideUrl: String) {
    let storySlideMediaId = "cached.slide." + slideWithId
    
    var slidesDownloadedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storySlideMediaId)) as? [String] ?? []
    let slideWithIdExists = slidesDownloadedArray.contains(where: {
      $0.range(of: storySlideMediaId) != nil
    })
    
    if !slideWithIdExists {
      slidesDownloadedArray.append(storySlideMediaId)
      UserDefaults.standard.setValue(slidesDownloadedArray, for: UserDefaults.Key(storySlideMediaId))
    }
    
    let userInfo = ["url": actualSlideUrl] as [String: Any]
    NotificationCenter.default.post(name:Notification.Name(storySlideMediaId), object: userInfo)
  }
}

enum SlideType: String, Codable {
  case image = "image"
  case video = "video"
  case unknown = ""
}
