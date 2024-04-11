import UIKit
import REES46

class FiltersMainViewController: UIViewController {

    public let filtersDataSource = FiltersRoundedMenuCollection.testList
    //let filtersDataSource = FiltersRoundedMenuCollection.testList
    
    public var allFiltersFinal: [String : Filter]?
    public var indFiltersFinal: IndustrialFilters?

    var collectionView: FiltersMenuCollection!
    let menuStack = FiltersRoundedButtonMenuStack()
    
    @IBOutlet private weak var backButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBackground()
        setupMenuCollection()
        //setupFiltersRoundedButton()
        //setupMenuStack()
    }
    
    private func setupBackground() {
        let backgroundImage = UIImageView()
        //backgroundImage.image = #imageLiteral(resourceName: "rg24")
        view.addSubview(backgroundImage)
        backgroundImage.constrainEdges(to: view)
    }
}

extension FiltersMainViewController: FiltersMenuCollectionDelegate {
    func setupMenuCollection() {
        collectionView = FiltersMenuCollection(fMenuItems: filtersDataSource)
        view.addSubview(collectionView)
        
        collectionView.menuCollectionDelegate = self
        collectionView.constrainWidth(self.view.frame.width)
        
        collectionView.constrainEdgesVertically(to: view)
        collectionView.constrainEdgesHorizontally(to: view)
        collectionView.constrainTop(to: view)
        //collectionView.constrainLeft(to: view)
        //collectionView.constrainRight(to: view)
    }
    
    func filtersMenuCollection(didSelectItemAt index: Int) {
        print("SDK: FiltersMainViewController collection tapped at \(filtersDataSource[index].name)")
    }
}

extension FiltersMainViewController {
    private func setupFiltersRoundedButton() {
        let customButton = FiltersRoundedButton(hasBlurEffect: true)
        customButton.setTitle("SDK: Title \n Page")
        view.addSubview(customButton)
        
        customButton.constrainCenterX(to: view)
        customButton.constrainCenterY(to: view)
        customButton.addTarget(self, action: #selector(sdkFilterPageItemButtonTapped), for: .touchUpInside)
    }
    
    @objc
    func sdkFilterPageItemButtonTapped(_ button: UIButton) {
        print("SDK: Title Page button tapped")
    }
}

extension FiltersMainViewController: FiltersRoundedButtonStackDelegate {
    func setupMenuStack() {
        menuStack.filtersRoundedButtonStackDelegate = self
        menuStack.configure(fMenuItems: filtersDataSource)
        view.addSubview(menuStack)
        
        menuStack.constrainEdgesVertically(to: view)
        menuStack.constrainTrailing(to: view)
        menuStack.constrainWidth(160)
    }
    
    func filtersMenuStack(didSelectAtIndex index: Int) {
        print("SDK: FiltersMainViewController stack tapped for \(filtersDataSource[index].name)")
    }
}
