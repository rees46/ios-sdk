import UIKit

class FiltersWidgetTagsView: UIViewController {

    @IBOutlet weak var tabelView: UITableView!
    
    public var menuList = [FiltersDataMenuList]()
    
    @IBOutlet private weak var backButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        tabelView.register(UINib.init(nibName: "FiltersWidgetTagsDoneCell", bundle: nil), forCellReuseIdentifier:"FiltersWidgetTagsDoneCell")
        
        tabelView.rowHeight = UITableView.automaticDimension
        tabelView.estimatedRowHeight = 100
        tabelView.backgroundColor = .darkGray
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is FiltersWidgetTagsView {
            let filtersTagsView = segue.destination as? FiltersTagsSlideViewController
            filtersTagsView?.filtersMenuList = menuList.filter{$0.selected}
        }
    }
    
    @objc private func didTapBack() {
        self.dismiss(animated: false, completion: nil)
    }
}

extension FiltersWidgetTagsView: UITableViewDataSource, UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FiltersTagsDetailTableViewCell") as! FiltersTagsDetailTableViewCell
            
            return cell
        }  else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FiltersTagsTableViewCell") as! FiltersTagsTableViewCell
            //cell.menuList = menuList
            
            let index = indexPath.row
            let filtersList = menuList[index]
            cell.menuList = [filtersList]
            
            cell.delegate = self
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = tableView.dequeueReusableCell(withIdentifier: FiltersTagsHelper.String.tagsCell) as! FiltersTagsTableViewCell
        if indexPath.row == 0 {
            //let cell = tableView.dequeueReusableCell(withIdentifier: "FiltersTagsDetailTableViewCell") as! FiltersTagsDetailTableViewCell
            return 60
        } else if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FiltersTagsDetailTableViewCell") as! FiltersTagsDetailTableViewCell
            return cell.bounds.height
        } else {
            return cell.bounds.height
        }
    }
}

extension FiltersWidgetTagsView: FiltersTagsTableViewCellDelegate {
    func didSelectedMenu(menu: FiltersDataMenuList) {
        if let tempMenu = menuList.first(where: {$0.titleValues == menu.titleValues}) {
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

extension FiltersWidgetTagsView: FiltersWidgetDoneDelegate {
    func didDoneTapped() {
        performSegue(withIdentifier: FiltersTagsHelper.String.toNextSegue, sender: self)
    }
}

