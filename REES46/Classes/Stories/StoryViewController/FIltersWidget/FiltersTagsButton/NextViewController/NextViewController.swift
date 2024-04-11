import UIKit

class NextViewController: UIViewController {
    
    var menuList = [FiltersMenu]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("menuList ",menuList.count)
        for (i, menu) in menuList.enumerated(){
            print("menu \(i+1) : \(menu.title)")
        }
    }
}
