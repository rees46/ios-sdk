import UIKit

class FiltersTagsViewController: UIViewController {

    @IBOutlet weak var tabelView: UITableView!
    
    public var menuList = [FiltersTagsMenu]()
    
    public var allFiltersFinal1: [String : Filter]?
    public var indFiltersFinal1: IndustrialFilters?
    @IBOutlet private weak var backButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        tabelView.register(UINib.init(nibName: "TagsDoneTableViewCell", bundle: nil), forCellReuseIdentifier:"TagsDoneTableViewCell")
        
        tabelView.rowHeight = UITableView.automaticDimension
        tabelView.estimatedRowHeight = 100
        tabelView.backgroundColor = .darkGray
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is TagsSlideViewController {
            let vc = segue.destination as? TagsSlideViewController
            vc?.filtersMenuList = menuList.filter{$0.selected}
        }
    }
    
    @objc private func didTapBack() {
        self.dismiss(animated: false, completion: nil)
    }
}

extension FiltersTagsViewController: UITableViewDataSource, UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "tagsDetailCell") as! TagsDetailTableViewCell
            
            return cell
        }  else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "tagsCell") as! TagsTableViewCell
            //cell.menuList = menuList
            
            let index = indexPath.row
            let filtersList = menuList[index]
            cell.menuList = [filtersList]
            
            cell.delegate = self
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = tableView.dequeueReusableCell(withIdentifier: TagsHelper.String.tagsCell) as! TagsTableViewCell
        // let layout = cell.collectionView.frame.size.height
        if indexPath.row == 0 {
            //let cell = tableView.dequeueReusableCell(withIdentifier: "tagsDetailCell") as! TagsDetailTableViewCell
            return 60
        } else if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "tagsDetailCell") as! TagsDetailTableViewCell
            return cell.bounds.height
        } else {
            return cell.bounds.height
        }
        // return cell.bounds.height

    }
}

extension FiltersTagsViewController: MenuTableViewCellDelegate{
    func didSelectedMenu(menu: FiltersTagsMenu) {
        if let tempMenu = menuList.first(where: {$0.titleValues == menu.titleValues}) {
            // print("selected \(menu.title) \(menu.selected)")
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
        performSegue(withIdentifier: TagsHelper.String.toNextSegue, sender: self)
    }
}

