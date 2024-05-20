import UIKit

open class FiltersTagsTableViewCell: UITableViewCell {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    public var collectionViewHeightConstraint: NSLayoutConstraint!
    
    var delegate: FiltersTagsTableViewCellDelegate?
    
    var cellFiltersList = [FiltersDataMenuList]()

    public override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.backgroundColor = UIColor.red
    }
    
    public override func layoutSubviews() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.reloadData()
    }

    public override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

extension FiltersTagsTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let index = section
        let count = cellFiltersList[index].titleValues.count
        
        return count
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FiltersTagsCollectionViewCell", for: indexPath) as! FiltersTagsCollectionViewCell
        
        let index = indexPath.row
        _ = cellFiltersList[indexPath.section].titleValues[index]
        cell.tagsFiltersData = cellFiltersList[indexPath.section]
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectedMenu(menu: cellFiltersList[indexPath.section])
    }
}

protocol FiltersTagsTableViewCellDelegate {
    func didSelectedMenu(menu: FiltersDataMenuList)
}
