import CoreGraphics
import SwiftUI
import UIKit

@available(tvOS 13.0, iOS 13.0, *)
extension Font {
    init(font: UIFont.TextStyle, size: CGFloat) {
		self = Font.custom(font.rawValue, size: size)
	}
}
