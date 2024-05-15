import UIKit

open class FiltersWidgetTagsView: UIViewController {

    @IBOutlet weak var tabelView: UITableView!
    
    public var filtersList = [FiltersDataMenuList]()
    
    @IBOutlet private weak var backButton: UIButton!

    open override func viewDidLoad() {
        super.viewDidLoad()
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        tabelView.register(UINib.init(nibName: "FiltersWidgetTagsDoneCell", bundle: nil), forCellReuseIdentifier:"FiltersWidgetTagsDoneCell")
        
        tabelView.rowHeight = UITableView.automaticDimension
        tabelView.estimatedRowHeight = 100
        tabelView.backgroundColor = .darkGray
    }
    
    open override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is FiltersWidgetTagsView {
            let filtersTagsView = segue.destination as? FiltersTagsSlideViewController
            filtersTagsView?.filtersMenuList = filtersList.filter{$0.selected}
        }
    }
    
    @objc private func didTapBack() {
        self.dismiss(animated: false, completion: nil)
    }
}

extension FiltersWidgetTagsView: UITableViewDataSource, UITableViewDelegate{
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filtersList.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FiltersTagsDetailTableViewCell") as! FiltersTagsDetailTableViewCell
            
            return cell
        }  else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FiltersTagsTableViewCell") as! FiltersTagsTableViewCell
            //cell.menuList = menuList
            
            let index = indexPath.row
            let filtersList = filtersList[index]
            cell.cellFiltersList = [filtersList]
            
            cell.delegate = self
            return cell
        }
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = tableView.dequeueReusableCell(withIdentifier: FiltersTagsHelper.String.tagsCell) as! FiltersTagsTableViewCell
        if indexPath.row == 0 {
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
        if let filterMapMenu = filtersList.first(where: {$0.titleValues == menu.titleValues}) {
            if filterMapMenu.selected {
                filtersList.filter {$0.filterId == menu.filterId}.first?.selected = false
            } else {
                filtersList.filter {$0.filterId == menu.filterId}.first?.selected = true
            }
            tabelView.reloadData()
        } else {
            print("SDK: Filters didSelected from list not found")
        }
    }
}

extension FiltersWidgetTagsView: FiltersWidgetDoneDelegate {
    func didDoneTapped() {
        performSegue(withIdentifier: FiltersTagsHelper.String.toNextSegue, sender: self)
    }
}

