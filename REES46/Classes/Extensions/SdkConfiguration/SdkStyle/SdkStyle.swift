import UIKit

public class SdkStyle: NSObject {

    public static var shared: SdkStyle = {
        return SdkStyle()
    }()

    private static let animationDuration = 0.2

    private struct WeakViewControllerContainer {
        weak var viewController: UIViewController?
    }

    private var viewControllers: [WeakViewControllerContainer] = []
    
    public var colorSchemes: [String: SdkStyleColorScheme] = [:]
    public var currentColorScheme: SdkStyleColorScheme? = nil
    public var currentStoriesBlockColorScheme: sdkElement_storiesBlockColorScheme? = nil
    public var fonts: [String: SdkStyleCustomFonts] = [:]
    public var currentFonts: SdkStyleCustomFonts? = nil

    private override init() {
        super.init()
    }

    public static let configure: Void = {
        UIView.swizzleWillMove
        UIViewController.swizzleViewDidLoad
    }()

    public func register(colorScheme: SdkStyleColorScheme, for key: SdkApperanceViewScheme) {
        colorSchemes[key.SdkApperanceViewScheme()] = colorScheme
    }

    public func register(fonts: SdkStyleCustomFonts, for key: SdkApperanceViewScheme) {
        self.fonts[key.SdkApperanceViewScheme()] = fonts
    }

    public func switchApppearance(to key: SdkApperanceViewScheme, animated: Bool) {
        guard let colorScheme = colorSchemes[key.SdkApperanceViewScheme()] else {
            return
        }

        currentColorScheme = colorScheme

        for viewControllerContainer in viewControllers {
            if let viewController = viewControllerContainer.viewController {
                viewController.applyColorScheme(colorScheme, animated: animated)
            }
        }
    }

    public func switchFontSize(to key: SdkApperanceViewScheme) {
        guard let fonts = fonts[key.SdkApperanceViewScheme()] else {
            return
        }

        currentFonts = fonts

        for viewControllerContainer in viewControllers {
            if let viewController = viewControllerContainer.viewController {
                viewController.applySdkCustomFonts(fonts)
            }
        }
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let view = object as? UIView,
            keyPath == #keyPath(UIView.isHidden) {
            if let currentColorScheme = currentColorScheme {
                view.downcastColorScheme(currentColorScheme, animated: false)
            }
            if let currentFonts = currentFonts {
                view.downcastSdkAllFonts(currentFonts)
            }
        }
    }

    internal func registerViewController(_ viewController: UIViewController) {
        print("SDK: SdkStyle registers view controller: \(String(describing: type(of: viewController)))")
        if blacklist.contains(String(describing: type(of: viewController))) {
            return
        }

        viewControllers.append(WeakViewControllerContainer(viewController: viewController))

        if let currentColorScheme = currentColorScheme {
            viewController.applyColorScheme(currentColorScheme, animated: false)
        }
        if let currentFonts = currentFonts {
            viewController.applySdkCustomFonts(currentFonts)
        }
    }

    internal static func applySdkStyleApperance(animated: Bool, block: @escaping (() -> Void)) {
        if animated {
            UIView.animate(withDuration: animationDuration, animations: block)
        }
        else {
            block()
        }
    }

    fileprivate var blacklist: [String] = []

    public func blackListVC(_ type: UIViewController.Type) {
        blacklist.append(String(describing: type))
    }

    public func blackListVC(name: String) {
        blacklist.append(name)
    }
}

extension UIView {
    @objc func apppear_willMove(toSuperview newSuperview: UIView?) {
        apppear_willMove(toSuperview: newSuperview)


        let blacklisted: Bool
        if let parentVC = self.parentViewController,
            SdkStyle.shared.blacklist.contains(String(describing: type(of: parentVC))) {
            blacklisted = true
        }
        else {
            blacklisted = false
        }


        if !blacklisted,
            newSuperview != nil {
            if let currentColorScheme = SdkStyle.shared.currentColorScheme {
                downcastColorScheme(currentColorScheme, animated: false)
            }
            if let currentFonts = SdkStyle.shared.currentFonts {
                downcastSdkAllFonts(currentFonts)
            }
        }

        if self is UITableViewCell {
            if newSuperview != nil {
                addObserver(SdkStyle.shared, forKeyPath: #keyPath(UIView.isHidden), options: [.new], context: nil)
            }
            else {
                removeObserver(SdkStyle.shared, forKeyPath: #keyPath(UIView.isHidden))
            }
        }
    }

    fileprivate static let swizzleWillMove: Void = {
        let originalMethod = class_getInstanceMethod(UIView.self, #selector(willMove(toSuperview:)))
        let swizzledMethod = class_getInstanceMethod(UIView.self, #selector(apppear_willMove(toSuperview:)))

        if let originalMethod = originalMethod,
            let swizzledMethod = swizzledMethod {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }()
}

extension UIViewController {
    @objc func apppear_viewDidLoad() {
        apppear_viewDidLoad()
        SdkStyle.shared.registerViewController(self)
    }

    fileprivate static let swizzleViewDidLoad: Void = {
        let originalMethod = class_getInstanceMethod(UIViewController.self, #selector(viewDidLoad))
        let swizzledMethod = class_getInstanceMethod(UIViewController.self, #selector(apppear_viewDidLoad))
        if let originalMethod = originalMethod,
            let swizzledMethod = swizzledMethod {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }()
}
