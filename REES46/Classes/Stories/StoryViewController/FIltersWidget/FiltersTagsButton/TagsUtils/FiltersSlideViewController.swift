import UIKit

class MenuSlideViewController: UIViewController {
    
    var filtersMenuList = [FiltersMenu]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("menuList ", filtersMenuList.count)
        for (i, menu) in filtersMenuList.enumerated(){
            print("menu \(i+1) : \(menu.title)")
        }
    }
}
