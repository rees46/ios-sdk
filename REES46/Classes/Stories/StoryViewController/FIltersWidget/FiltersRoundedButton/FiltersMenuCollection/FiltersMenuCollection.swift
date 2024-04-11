import UIKit

protocol FiltersMenuCollectionDelegate: AnyObject {
    func filtersMenuCollection(didSelectItemAt index: Int)
}

private extension UICollectionViewCell {
    static func reuseId() -> String {
        return String(describing: self)
    }
}

class FiltersMenuCollection: UICollectionView {
    
    weak var menuCollectionDelegate: FiltersMenuCollectionDelegate?
    
    let filtersDataSource: [FiltersRoundedMenuCollection]
    
    private let cellItemHeight : CGFloat = 48
    private let cellMinLineSpacing : CGFloat = 8
    private let cellMinInterItemSpacing : CGFloat = 10
    private let cellFont = UIFont.boldSystemFont(ofSize: 17)
    
    init(fMenuItems: [FiltersRoundedMenuCollection]) {
        
        self.filtersDataSource = fMenuItems
        
        let layout = FiltersMenuCollectionViewFlowLayout()
        super.init(frame: CGRect.zero, collectionViewLayout: layout)
        
        register(FiltersMenuCollectionViewCell.self, forCellWithReuseIdentifier: FiltersMenuCollectionViewCell.reuseId())

        dataSource = self
        delegate = self
        
        backgroundColor = .clear
        showsVerticalScrollIndicator = false
        isScrollEnabled = true
        alwaysBounceVertical = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FiltersMenuCollection: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        menuCollectionDelegate?.filtersMenuCollection(didSelectItemAt: indexPath.row)
    }
}

extension FiltersMenuCollection: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filtersDataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FiltersMenuCollectionViewCell.reuseId(), for: indexPath) as! FiltersMenuCollectionViewCell
        let index = indexPath.row
        let menuItem = filtersDataSource[index]
        cell.configure(title: menuItem.name, font: cellFont, didTapCell: { [weak self] in
            self?.menuCollectionDelegate?.filtersMenuCollection(didSelectItemAt: index)
        })
        return cell
    }
}

extension FiltersMenuCollection: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 10)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return cellMinLineSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return cellMinInterItemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return self.calculateCellSize(content: filtersDataSource[indexPath.row].name as NSString)
    }
    
    private func calculateCellSize(content : NSString) -> CGSize {
        let size: CGSize = content.size(withAttributes: [NSAttributedString.Key.font : cellFont])
        return CGSize(width: size.width + 40, height: cellItemHeight)
    }
}
