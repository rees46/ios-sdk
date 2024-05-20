import UIKit

public class FiltersTagsSlideViewController: UIViewController {
    
    var filtersMenuList = [FiltersDataMenuList]()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        //print("filtersMenuList ", filtersMenuList.count)
        for (i, menu) in filtersMenuList.enumerated(){
            print("filtersMenuList \(i+1) : \(menu.title)")
        }
    }
}
