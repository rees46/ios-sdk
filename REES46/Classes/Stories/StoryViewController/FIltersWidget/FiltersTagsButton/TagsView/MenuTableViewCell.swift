import UIKit

class MenuTableViewCell: UITableViewCell {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    public var collectionViewHeightConstraint: NSLayoutConstraint!
    
    var delegate: MenuTableViewCellDelegate?
    
    var menuList = [FiltersMenu]()

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.backgroundColor = UIColor.red
    }
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
    
    override func layoutSubviews() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.reloadData()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

extension MenuTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let index = section
        let count = menuList[index].titleValues.count
        
        return count
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "menuCollectionViewCell", for: indexPath) as! MenuCollectionViewCell
        
        let index = indexPath.row
        let menuItem = menuList[indexPath.section].titleValues[index]
        cell.menu = menuList[indexPath.section]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectedMenu(menu: menuList[indexPath.section])
    }
}

protocol MenuTableViewCellDelegate {
    func didSelectedMenu(menu: FiltersMenu)
}
