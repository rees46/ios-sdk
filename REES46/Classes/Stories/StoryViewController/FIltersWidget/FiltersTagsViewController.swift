import UIKit
import REES46

class FiltersTagsViewController: UIViewController {

    @IBOutlet weak var tabelView: UITableView!
    
    public var menuList = [FiltersMenu]()
    
    public var allFiltersFinal1: [String : Filter]?
    public var indFiltersFinal1: IndustrialFilters?
    @IBOutlet private weak var backButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)//
        tabelView.register(UINib.init(nibName: "DoneTableViewCell", bundle: nil), forCellReuseIdentifier:"DoneTableViewCell")
        
        tabelView.rowHeight = UITableView.automaticDimension
        tabelView.estimatedRowHeight = 100
        tabelView.backgroundColor = .green
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is NextViewController
        {
            let vc = segue.destination as? NextViewController
            vc?.menuList = menuList.filter{$0.selected}
        }
    }
    
    @objc private func didTapBack() {
        self.dismiss(animated: false, completion: nil)
    }
}

extension FiltersTagsViewController: UITableViewDataSource, UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //let ss = menuList[section].titleValues.count
        return menuList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "tagsCell") as! DetailTableViewCell
            
            return cell
        }  else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "menuCell") as! MenuTableViewCell
    //        cell.menuList = menuList
            
            let index = indexPath.row
            let menuItem5 = menuList[index]
            
            cell.menuList = [menuItem5]
            
            cell.delegate = self
            //let cell = tableView.dequeueReusableCell(withIdentifier: "DoneTableViewCell") as! DoneTableViewCell
            //cell.delegate = self
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "menuCell") as! MenuTableViewCell
//        cell.menuList = menuList
        
        let index = indexPath.row
        let menuItem5 = menuList[index]
        
        
        
        cell.menuList = [menuItem5]
        
        cell.delegate = self
        //let cell = tableView.dequeueReusableCell(withIdentifier: "DoneTableViewCell") as! DoneTableViewCell
        //cell.delegate = self
        return cell
        
//        switch indexPath.row {
//        case 0:
//            let cell = tableView.dequeueReusableCell(withIdentifier: "tagsCell") as! DetailTableViewCell
//            return cell
//        case 1:
//            let cell = tableView.dequeueReusableCell(withIdentifier: "menuCell") as! MenuTableViewCell
//            cell.menuList = menuList
//            cell.delegate = self
//            return cell
//
//        default:
//            let cell = tableView.dequeueReusableCell(withIdentifier: "menuCell") as! MenuTableViewCell
//            cell.menuList = menuList
//            
//            let index = indexPath.row
//            let menuItem = menuList[index]
//            
//            cell.delegate = self
//            //let cell = tableView.dequeueReusableCell(withIdentifier: "DoneTableViewCell") as! DoneTableViewCell
//            //cell.delegate = self
//            return cell
//        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = tableView.dequeueReusableCell(withIdentifier: K.String.menuCell) as! MenuTableViewCell
        let layout = cell.collectionView.frame.size.height
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "tagsCell") as! DetailTableViewCell
            return 60
        } else if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "tagsCell") as! DetailTableViewCell
            return cell.bounds.height
        } else {
            return cell.bounds.height
        }
        return cell.bounds.height
//        switch indexPath.row {
//        case 0:
//            let cell = tableView.dequeueReusableCell(withIdentifier: K.String.tagsCell) as! DetailTableViewCell
//            return cell.bounds.height
//        case 1:
//            let cell = tableView.dequeueReusableCell(withIdentifier: K.String.menuCell) as! MenuTableViewCell
//            return cell.bounds.height
//
//        default:
//            let cell = tableView.dequeueReusableCell(withIdentifier: K.String.doneTableViewCell) as! DoneTableViewCell
//            return cell.bounds.height
//
//        }
    }
}

extension FiltersTagsViewController: MenuTableViewCellDelegate{
    func didSelectedMenu(menu: FiltersMenu) {
        if let tempMenu = menuList.first(where: {$0.titleValues == menu.titleValues}) {
//            print("selected \(menu.title) \(menu.selected)")
            if tempMenu.selected {
                menuList.filter {$0.filterId == menu.filterId}.first?.selected = false
            } else {
                menuList.filter {$0.filterId == menu.filterId}.first?.selected = true
            }
            tabelView.reloadData()
        } else {
           print("SDK: Filters didSelectedMenu not found")
        }
    }
}

extension FiltersTagsViewController: DoneDelegate{
    func didDoneTapped() {
        performSegue(withIdentifier: K.String.toNextSegue, sender: self)
    }
}

