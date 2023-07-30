import UIKit

public extension UIViewController {
  
  @objc
  func presentWebKit(urlRequest: URLRequest, titleHidden:Bool = false, completion: (() -> Void)? = nil) {
      let rweb = RWebViewController()
      rweb.request = urlRequest
      rweb.modalPresentationStyle = .overCurrentContext
      rweb.titleHidden = titleHidden
      present(rweb, animated: true, completion: completion)
  }
  
  @objc
  func presentInternalSdkWebKit(url: URL, titleHidden:Bool = false, completion: (() -> Void)? = nil) {
      let urlRequest = URLRequest(url: url)
      presentWebKit(urlRequest: urlRequest, titleHidden: titleHidden, completion: completion)
  }
}
