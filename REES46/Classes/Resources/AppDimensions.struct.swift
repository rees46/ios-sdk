import UIKit

struct AppDimensions {
    
    struct Padding {
        static let small: CGFloat = 8.0
        static let medium: CGFloat = 16.0
        static let large: CGFloat = 24.0
    }
    
    struct Height {
        static let popUpButton: CGFloat = 44.0
        static let button: CGFloat = 50.0
        static let snackbar: CGFloat = 50.0
    }
    
    struct Size {
        static let small: CGFloat = 5.0
        static let medium: CGFloat = 10.0
        static let large: CGFloat = 20.0
        static let closeButtonSize: CGFloat = 26.0
        static let alertPopUpHeight: CGFloat = 200.0
        static let fullScreenImageHeight: CGFloat = 240.0
        static let bottomSheetHeight: CGFloat = 300.0
        static let crossSize: CGFloat = 12.0
        static let crossLineWidth: CGFloat = 2.0
        static let closeButtonCornerRadius: CGFloat = 13.0
    }
    
    struct FontSize {
        static let extraSmall: CGFloat = 8.0
        static let small: CGFloat = 12.0
        static let medium: CGFloat = 16.0
        static let large: CGFloat = 20.0
        static let extraLarge: CGFloat = 24.0
    }
    
    struct Animation {
        static let duration: TimeInterval = 0.3
        static let snackbarTranslationY: CGFloat = 100.0
    }
    
    struct Offset{
        static let topOffset: CGFloat = 7.0
        static let leftOffset: CGFloat = 7.0
    }
}
