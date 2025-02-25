import UIKit
import WebKit

public class RWebViewManager {
  
  private var urlSession: URLSession
  private var urlHandler: URLHandler
  
  public init() {
    let configuration = URLSessionConfiguration.default
    self.urlSession = URLSession(configuration: configuration)
    self.urlHandler = UIApplicationHandler()
  }
  
  public func openURL(_ urlString: String, needOpeningWebView: Bool, from viewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let url = URL(string: urlString) else {
      completion(.failure(WrongUrlError.invalidURL))
      return
    }
    if isHttpURL(url) {
      if needOpeningWebView {
        openInWebView(url, from: viewController)
        completion(.success(()))
      } else {
        urlHandler.open(url: url, completion: completion)
        completion(.success(()))
      }
    } else {
      completion(.failure(WrongUrlError.unsupportedURL))
    }
  }
  
  private func isHttpURL(_ url: URL) -> Bool {
    return url.scheme?.caseInsensitiveCompare("http") == .orderedSame || url.scheme?.caseInsensitiveCompare("https") == .orderedSame
  }
  
  private func openInWebView(_ url: URL, from viewController: UIViewController) {
    print("Opening in WebView: \(url)")
    viewController.presentWebKit(urlRequest: URLRequest(url: url))
  }
}

