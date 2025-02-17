import UIKit
import WebKit

public class RWebViewManager {
  
  public static let shared = RWebViewManager()
  
  private init() {}
  
  public func openURL(_ urlString: String, needOpeningWebView: Bool, from viewController: UIViewController) {
    guard let url = URL(string: urlString) else {
      print(WrongUrlError.failed("Wrong URL").localizedDescription)
      return
    }
    if isHttpURL(url) {
      if needOpeningWebView {
        openInWebView(url, from: viewController)
      } else {
        openInBrowser(url)
      }
    }
  }
  
  private func isHttpURL(_ url: URL) -> Bool {
    return url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https"
  }
  
  private func openInBrowser(_ url: URL) {
    print("Opening in browser: \(url)")
    UIApplication.shared.open(url, options: [:])
  }
  
  private func openInWebView(_ url: URL, from viewController: UIViewController) {
    print("Opening in WebView: \(url)")
    viewController.presentWebKit(urlRequest: URLRequest(url: url))
  }
}

