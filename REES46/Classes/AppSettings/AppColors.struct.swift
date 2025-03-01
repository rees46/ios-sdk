import UIKit

public struct AppColors {
    
    struct Background {
        static let alertDimmed: UIColor = UIColor.black.withAlphaComponent(0.6)
        static let contentView: UIColor = .white
        static let buttonPositive: UIColor = .systemBlue
        static let buttonNegative: UIColor = .gray
    }
    
    struct Text {
        static let title: UIColor = .black
        static let message: UIColor = .black
        static let buttonText: UIColor = .white
    }
    
    struct Button {
        static let positiveBackground: UIColor = .systemBlue
        static let negativeBackground: UIColor = .gray
        static let textColor: UIColor = .white
    }
    
    struct CloseButton {
        static let crossTint: UIColor = .black
        static let background: UIColor = .clear
        static let alpha: CGFloat = 1.0
    }
    
    struct ImageView {
        static let background: UIColor = .clear
    }
}
