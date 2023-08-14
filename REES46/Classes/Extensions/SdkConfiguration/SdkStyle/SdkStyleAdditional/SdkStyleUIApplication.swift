import UIKit
import Foundation

public protocol sdkStyleManagerProtocol {
    func setStoriesViewFont(fontName: String)
    func isDeviceDarkModeEnabled() -> Bool
    func getSession() -> String
}

@objc
public extension UIApplication {
    
    func setStoriesViewFont(fontName: String) {
        _ = {
            $0.isUserInteractionEnabled = true
            $0.font = UIFont(name: fontName, size: 14)
        }(UILabel.appearance())
    }
   
    func setStoriesViewBackgroundColor(color: UIColor) {
       _ = {
           $0.backgroundColor = .white
       }(UICollectionView.appearance())
    }
   
    func setupFullAppearanceTheme(_ tintColor: UIColor, barTintColor: UIColor) {
       _ = {
           $0.barTintColor = barTintColor
           $0.tintColor = tintColor
           $0.titleTextAttributes = [.foregroundColor: tintColor,
           ]
        }(UINavigationBar.appearance())
        
        if #available(iOS 11.0, *) {
            _ = {
                $0.tintColor = nil
            }(UINavigationBar.appearance(whenContainedInInstancesOf: [UIDocumentBrowserViewController.self]))
        }
        
        _ = {
            $0.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17), ], for: .normal)
            $0.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 15), ], for: .highlighted)
        }(UIBarButtonItem.appearance(whenContainedInInstancesOf: [UINavigationBar.self]))
        
        _ = {
            $0.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
        }(UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIImagePickerController.self]))
        
        _ = {
            $0.setTitleColor(.black, for: .normal)
            $0.titleLabel?.adjustsFontSizeToFitWidth = true
            $0.titleLabel?.minimumScaleFactor = 1.0
            $0.imageView?.contentMode = .scaleAspectFit
            $0.isExclusiveTouch = true
            $0.adjustsImageWhenHighlighted = false
        }(UIButton.appearance())
        
        if let aClass = NSClassFromString("UICalloutBarButton")! as? UIButton.Type {
            aClass.appearance().setTitleColor(.white, for: .normal)
        }
        
        _ = {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.showsHorizontalScrollIndicator = false
            $0.keyboardDismissMode = .onDrag
            if #available(iOS 11.0, *) {
                $0.contentInsetAdjustmentBehavior = .never
            }
        }(UIScrollView.appearance())
        
        _ = {
            $0.separatorInset = .zero
            $0.separatorStyle = .singleLine
            $0.rowHeight = 60
            $0.backgroundColor = .groupTableViewBackground
            if #available(iOS 11.0, *) {
                $0.estimatedRowHeight = 0.0
                $0.estimatedSectionHeaderHeight = 0.0
                $0.estimatedSectionFooterHeight = 0.0
            }
        }(UITableView.appearance())
        
        _ = {
            $0.layoutMargins = .zero
            $0.separatorInset = .zero
            $0.selectionStyle = .none
            $0.backgroundColor = .white
        }(UITableViewCell.appearance())
        
        _ = {
            $0.scrollsToTop = false
            $0.isPagingEnabled = true
            $0.bounces = false
        }(UICollectionView.appearance())
        
        _ = {
            $0.layoutMargins = .zero
            $0.backgroundColor = .white
        }(UICollectionViewCell.appearance())
        
        _ = {
            $0.isUserInteractionEnabled = true
        }(UIImageView.appearance())
        
        _ = {
            $0.isUserInteractionEnabled = true
        }(UILabel.appearance())
        
        _ = {
            $0.pageIndicatorTintColor = barTintColor
            $0.currentPageIndicatorTintColor = tintColor
            $0.isUserInteractionEnabled = true
            $0.hidesForSinglePage = true
        }(UIPageControl.appearance())
        
        _ = {
            $0.progressTintColor = barTintColor
            $0.trackTintColor = .clear
        }(UIProgressView.appearance())
        
        _ = {
            $0.minimumTrackTintColor = tintColor
            $0.autoresizingMask = .flexibleWidth
        }(UISlider.appearance())
        
        _ = {
            $0.onTintColor = tintColor
            $0.autoresizingMask = .flexibleWidth
          }(UISwitch.appearance())
    }
    
    var sdkCurrentKeyWindow: UIWindow? {
        get {
            if #available(iOS 13.0, *) {
                return UIApplication.shared.windows.filter({ $0.isKeyWindow }).first
            }
            return UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first
        }
    }
    
    var sdkCurrentViewController: UIViewController? {
        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else { return nil}
        
        if let presentedViewController = rootViewController.presentedViewController {
            if let navigationController = presentedViewController as? UINavigationController {
                return navigationController.topViewController
            }
            return presentedViewController
        }
        
        if let navigationController = rootViewController as? UINavigationController {
            return navigationController.topViewController
        }
        
        if let tabBarController = rootViewController as? UITabBarController {
            if let navigationController = tabBarController.selectedViewController as? UINavigationController{
                return navigationController.topViewController
            }
            return tabBarController.viewControllers?.first
        }
        return nil
        
    }
}
