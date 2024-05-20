import UIKit

public protocol sdkElement_storiesBlockColorScheme {
    var storiesBlockBackgroundColor: UIColor { get set }
}

public protocol SdkStyleColorScheme {
    var storiesBlockSelectFontName: UIFont { get set }
    var storiesBlockSelectFontSize: CGFloat { get set }
    var storiesBlockFontColor: UIColor { get set }
    var storiesBlockBackgroundColor: UIColor { get set }
    
    var defaultButtonSelectFontName: UIFont { get set }
    var defaultButtonSelectFontSize: CGFloat { get set }
    var defaultButtonFontColor: UIColor { get set }
    var defaultButtonBackgroundColor: UIColor { get set }
    
    var productsButtonSelectFontName: UIFont { get set }
    var productsButtonSelectFontSize: CGFloat { get set }
    var productsButtonFontColor: UIColor { get set }
    var productsButtonBackgroundColor: UIColor { get set }
    
    var viewControllerBackground: UIColor { get }
    var navigationBarStyle: UIBarStyle { get }
    var navigationBarBackgroundColor: UIColor { get }
    var navigationBarTextColor: UIColor { get }
}

public protocol SdkStyleViewColorScheme {
    var viewBackgroundColor: UIColor { get }
}

public protocol SdkStyleLabelColorScheme {
    var labelTextColor: UIColor { get }
}

public protocol SdkStyleButtonColorScheme {
    var buttonTintColor: UIColor { get }
}

public protocol SdkStyleTableViewColorScheme {
    var tableViewBackgroundColor: UIColor { get }
    var tableViewSeparatorColor: UIColor { get }
    var headerBackgroundColor: UIColor { get }
    var headerTextColorColor: UIColor { get }
    var cellBackgroundColor: UIColor { get }
    var cellTextColorColor: UIColor { get }
    var cellSubTextColorColor: UIColor { get }
}

public protocol SdkStyleCollectionViewColorScheme {
    var collectionViewBackgroundColor: UIColor { get }
    var cellBackgroundColor: UIColor { get }
    var cellTextColorColor: UIColor { get }
    var cellSubTextColorColor: UIColor { get }
}

public protocol SdkStyleDatePickerColorScheme {
    var datePickerTextColor: UIColor { get }
}

public protocol SdkStyleRefreshControlColorScheme {
    var refreshControlTintColor: UIColor { get }
    var refreshControlTextColor: UIColor { get }
}
