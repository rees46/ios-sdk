import UIKit

public protocol SearchResultsViewDelegate: AnyObject {
     func didSelectResult(_ result: SearchResult)
}
