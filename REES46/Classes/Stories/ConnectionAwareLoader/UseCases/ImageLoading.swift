import Foundation
import UIKit

protocol ImageLoading {
    func loadImage(from url: URL, completion: @escaping (Result<UIImage, Error>) -> Void)
}
