import Foundation
import UIKit

public class UIApplicationHandler: URLHandler {
  public func open(url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:], completionHandler: { success in
        if success {
          completion(.success(()))
        } else {
          completion(.failure(WrongUrlError.invalidURL))
        }
      })
    }
  }
}
