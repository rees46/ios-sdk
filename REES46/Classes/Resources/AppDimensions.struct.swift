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
        static let alertPopUpHeight: CGFloat = 200.0
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
}
