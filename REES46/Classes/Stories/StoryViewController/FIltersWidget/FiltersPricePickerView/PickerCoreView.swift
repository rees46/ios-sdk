import UIKit

@objc public protocol PickerCoreViewDataSource: AnyObject {
    func pickerCoreViewNumberOfRows(_ pickerCoreView: PickerCoreView) -> Int
    func pickerCoreView(_ pickerCoreView: PickerCoreView, titleForRow row: Int) -> String
}

@objc public protocol PickerCoreViewDelegate: AnyObject {
    func pickerCoreViewHeightForRows(_ pickerCoreView: PickerCoreView) -> CGFloat
    @objc optional func pickerCoreView(_ pickerCoreView: PickerCoreView, didSelectRow row: Int)
    @objc optional func pickerCoreView(_ pickerCoreView: PickerCoreView, didTapRow row: Int)
    @objc optional func pickerCoreView(_ pickerCoreView: PickerCoreView, styleForLabel label: UILabel, highlighted: Bool)
    @objc optional func pickerCoreView(_ pickerCoreView: PickerCoreView, viewForRow row: Int, highlighted: Bool, reusingView view: UIView?) -> UIView?
}

open class PickerCoreView: UIView {
    fileprivate class SimplePickerTableViewCell: UITableViewCell {
        lazy var titleLabel: UILabel = {
            let titleLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: self.contentView.frame.width, height: self.contentView.frame.height))
            titleLabel.textAlignment = .center
            
            return titleLabel
        }()
        
        var customView: UIView?
    }
    
    @objc public enum ScrollingStyle: Int {
        case `default`, infinite
    }
    
    @objc public enum SelectionStyle: Int {
        case none, defaultIndicator, overlay, image
    }
    
    var enabled = true {
        didSet {
            if enabled {
                turnPickerCoreViewOn()
            } else {
                turnPickerCoreViewOff()
            }
        }
    }
    
    fileprivate var selectionOverlayH: NSLayoutConstraint!
    fileprivate var selectionImageH: NSLayoutConstraint!
    fileprivate var selectionIndicatorB: NSLayoutConstraint!
    fileprivate var pickerCellBackgroundColor: UIColor?
    
    var numberOfRowsByDataSource: Int {
        get {
            return dataSource?.pickerCoreViewNumberOfRows(self) ?? 0
        }
    }

    fileprivate var indexesByDataSource: Int {
        get {
            return numberOfRowsByDataSource > 0 ? numberOfRowsByDataSource - 1 : numberOfRowsByDataSource
        }
    }
    
    var rowHeight: CGFloat {
        get {
            return delegate?.pickerCoreViewHeightForRows(self) ?? 0
        }
    }
    
    override open var backgroundColor: UIColor? {
        didSet {
            self.tableView.backgroundColor = self.backgroundColor
            self.pickerCellBackgroundColor = self.backgroundColor
        }
    }
    
    fileprivate let pickerCoreViewCellIdentifier = "pickerCoreViewCell"
    
    open weak var dataSource: PickerCoreViewDataSource?
    open weak var delegate: PickerCoreViewDelegate?
    
    open lazy var defaultSelectionIndicator: UIView = {
        let selectionIndicator = UIView()
        selectionIndicator.backgroundColor = self.tintColor
        selectionIndicator.alpha = 0.0
        
        return selectionIndicator
    }()
    
    open lazy var selectionOverlay: UIView = {
        let selectionOverlay = UIView()
        selectionOverlay.backgroundColor = self.tintColor
        selectionOverlay.alpha = 0.0
        
        return selectionOverlay
    }()
    
    open lazy var selectionImageView: UIImageView = {
        let selectionImageView = UIImageView()
        selectionImageView.alpha = 0.0
        
        return selectionImageView
    }()
    
    public lazy var tableView: UITableView = {
        let tableView = UITableView()
        
        return tableView
    }()
    
    fileprivate var infinityRowsMultiplier: Int = 1
    fileprivate var hasTouchedPickerCoreViewYet = false
    open var currentSelectedRow: Int!
    open var currentSelectedIndex: Int {
        get {
            return indexForRow(currentSelectedRow)
        }
    }
    
    fileprivate var firstTimeOrientationChanged = true
    fileprivate var orientationChanged = false
    fileprivate var screenSize: CGSize = UIScreen.main.bounds.size
    fileprivate var isScrolling = false
    fileprivate var setupHasBeenDone = false
    fileprivate var shouldSelectNearbyToMiddleRow = true
    
    open var scrollingStyle = ScrollingStyle.default {
        didSet {
            switch scrollingStyle {
            case .default:
                infinityRowsMultiplier = 1
            case .infinite:
                infinityRowsMultiplier = generateInfinityRowsMultiplier()
            }
        }
    }
    
    open var selectionStyle = SelectionStyle.none {
        didSet {
            setupSelectionViewsVisibility()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    fileprivate func setup() {
        infinityRowsMultiplier = generateInfinityRowsMultiplier()
        
        translatesAutoresizingMaskIntoConstraints = false
        setupTableView()
        setupSelectionOverlay()
        setupSelectionImageView()
        setupDefaultSelectionIndicator()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.reloadData()
        
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.adjustSelectionOverlayHeightConstraint()
        }
    }
    
    fileprivate func setupTableView() {
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.separatorColor = .none
        tableView.allowsSelection = true
        tableView.allowsMultipleSelection = false
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        tableView.scrollsToTop = false
        tableView.register(SimplePickerTableViewCell.classForCoder(), forCellReuseIdentifier: self.pickerCoreViewCellIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)
        
        let tableViewH = NSLayoutConstraint(item: tableView, attribute: .height, relatedBy: .equal, toItem: self,
                                                attribute: .height, multiplier: 1, constant: 0)
        addConstraint(tableViewH)
        
        let tableViewW = NSLayoutConstraint(item: tableView, attribute: .width, relatedBy: .equal, toItem: self,
                                                attribute: .width, multiplier: 1, constant: 0)
        addConstraint(tableViewW)
        
        let tableViewL = NSLayoutConstraint(item: tableView, attribute: .leading, relatedBy: .equal, toItem: self,
                                                attribute: .leading, multiplier: 1, constant: 0)
        addConstraint(tableViewL)
        
        let tableViewTop = NSLayoutConstraint(item: tableView, attribute: .top, relatedBy: .equal, toItem: self,
                                                attribute: .top, multiplier: 1, constant: 0)
        addConstraint(tableViewTop)
        
        let tableViewBottom = NSLayoutConstraint(item: tableView, attribute: .bottom, relatedBy: .equal, toItem: self,
                                                    attribute: .bottom, multiplier: 1, constant: 0)
        addConstraint(tableViewBottom)
        
        let tableViewT = NSLayoutConstraint(item: tableView, attribute: .trailing, relatedBy: .equal, toItem: self,
                                                attribute: .trailing, multiplier: 1, constant: 0)
        addConstraint(tableViewT)
    }

    fileprivate func setupSelectionViewsVisibility() {
        switch selectionStyle {
        case .defaultIndicator:
            defaultSelectionIndicator.alpha = 1.0
            selectionOverlay.alpha = 0.0
            selectionImageView.alpha = 0.0
        case .overlay:
            selectionOverlay.alpha = 0.25
            defaultSelectionIndicator.alpha = 0.0
            selectionImageView.alpha = 0.0
        case .image:
            selectionImageView.alpha = 1.0
            selectionOverlay.alpha = 0.0
            defaultSelectionIndicator.alpha = 0.0
        case .none:
            selectionOverlay.alpha = 0.0
            defaultSelectionIndicator.alpha = 0.0
            selectionImageView.alpha = 0.0
        }
    }
    
    fileprivate func setupSelectionOverlay() {
        selectionOverlay.isUserInteractionEnabled = false
        selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(selectionOverlay)
        
        selectionOverlayH = NSLayoutConstraint(item: selectionOverlay, attribute: .height, relatedBy: .equal, toItem: nil,
                                                attribute: .notAnAttribute, multiplier: 1, constant: rowHeight)
        self.addConstraint(selectionOverlayH)
        
        let selectionOverlayW = NSLayoutConstraint(item: selectionOverlay, attribute: .width, relatedBy: .equal, toItem: self,
                                                    attribute: .width, multiplier: 1, constant: 0)
        addConstraint(selectionOverlayW)
        
        let selectionOverlayL = NSLayoutConstraint(item: selectionOverlay, attribute: .leading, relatedBy: .equal, toItem: self,
                                                    attribute: .leading, multiplier: 1, constant: 0)
        addConstraint(selectionOverlayL)
        
        let selectionOverlayT = NSLayoutConstraint(item: selectionOverlay, attribute: .trailing, relatedBy: .equal, toItem: self,
                                                    attribute: .trailing, multiplier: 1, constant: 0)
        addConstraint(selectionOverlayT)
        
        let selectionOverlayY = NSLayoutConstraint(item: selectionOverlay, attribute: .centerY, relatedBy: .equal, toItem: self,
                                                    attribute: .centerY, multiplier: 1, constant: 0)
        addConstraint(selectionOverlayY)
    }
    
    fileprivate func setupSelectionImageView() {
        selectionImageView.isUserInteractionEnabled = false
        selectionImageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(selectionImageView)
        
        selectionImageH = NSLayoutConstraint(item: selectionImageView, attribute: .height, relatedBy: .equal, toItem: nil,
                                                attribute: .notAnAttribute, multiplier: 1, constant: rowHeight)
        self.addConstraint(selectionImageH)
        
        let selectionImageW = NSLayoutConstraint(item: selectionImageView, attribute: .width, relatedBy: .equal, toItem: self,
                                                    attribute: .width, multiplier: 1, constant: 0)
        addConstraint(selectionImageW)
        
        let selectionImageL = NSLayoutConstraint(item: selectionImageView, attribute: .leading, relatedBy: .equal, toItem: self,
                                                    attribute: .leading, multiplier: 1, constant: 0)
        addConstraint(selectionImageL)
        
        let selectionImageT = NSLayoutConstraint(item: selectionImageView, attribute: .trailing, relatedBy: .equal, toItem: self,
                                                    attribute: .trailing, multiplier: 1, constant: 0)
        addConstraint(selectionImageT)
        
        let selectionImageY = NSLayoutConstraint(item: selectionImageView, attribute: .centerY, relatedBy: .equal, toItem: self,
                                                    attribute: .centerY, multiplier: 1, constant: 0)
        addConstraint(selectionImageY)
    }
    
    fileprivate func setupDefaultSelectionIndicator() {
        defaultSelectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(defaultSelectionIndicator)
        
        let selectionIndicatorH = NSLayoutConstraint(item: defaultSelectionIndicator, attribute: .height, relatedBy: .equal, toItem: nil,
                                                        attribute: .notAnAttribute, multiplier: 1, constant: 2.0)
        addConstraint(selectionIndicatorH)
        
        let selectionIndicatorW = NSLayoutConstraint(item: defaultSelectionIndicator, attribute: .width, relatedBy: .equal,
                                                        toItem: self, attribute: .width, multiplier: 1, constant: 0)
        addConstraint(selectionIndicatorW)
        
        let selectionIndicatorL = NSLayoutConstraint(item: defaultSelectionIndicator, attribute: .leading, relatedBy: .equal,
                                                        toItem: self, attribute: .leading, multiplier: 1, constant: 0)
        addConstraint(selectionIndicatorL)
        
        selectionIndicatorB = NSLayoutConstraint(item: defaultSelectionIndicator, attribute: .bottom, relatedBy: .equal,
                                                    toItem: self, attribute: .centerY, multiplier: 1, constant: (rowHeight / 2))
        addConstraint(selectionIndicatorB)
        
        let selectionIndicatorT = NSLayoutConstraint(item: defaultSelectionIndicator, attribute: .trailing, relatedBy: .equal,
                                                        toItem: self, attribute: .trailing, multiplier: 1, constant: 0)
        addConstraint(selectionIndicatorT)
    }
    
    fileprivate func generateInfinityRowsMultiplier() -> Int {
        if scrollingStyle == .default {
            return 1
        }

        if numberOfRowsByDataSource > 100 {
            return 100
        } else if numberOfRowsByDataSource < 100 && numberOfRowsByDataSource > 50 {
            return 200
        } else if numberOfRowsByDataSource < 50 && numberOfRowsByDataSource > 25 {
            return 400
        } else {
            return 800
        }
    }
    
    open override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        
        if let _ = newWindow {
            NotificationCenter.default.addObserver(self, selector: #selector(PickerCoreView.adjustCurrentSelectedAfterOrientationChanges),
                                                            name: UIDevice.orientationDidChangeNotification, object: nil)
        } else {
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        if !setupHasBeenDone {
            setup()
            setupHasBeenDone = true
        }
    }
    
    fileprivate func adjustSelectionOverlayHeightConstraint() {
        if selectionOverlayH.constant != rowHeight || selectionImageH.constant != rowHeight || selectionIndicatorB.constant != (rowHeight / 2) {
            selectionOverlayH.constant = rowHeight
            selectionImageH.constant = rowHeight
            selectionIndicatorB.constant = -(rowHeight / 2)
            layoutIfNeeded()
        }
    }
    
    @objc
    func adjustCurrentSelectedAfterOrientationChanges() {
        guard screenSize != UIScreen.main.bounds.size else {
            return
        }

        screenSize = UIScreen.main.bounds.size

        setNeedsLayout()
        layoutIfNeeded()
        
        shouldSelectNearbyToMiddleRow = true
        
        if firstTimeOrientationChanged {
            firstTimeOrientationChanged = false
            return
        }
        
        if !isScrolling {
            return
        }
        
        orientationChanged = true
    }
    
    fileprivate func indexForRow(_ row: Int) -> Int {
        return row % (numberOfRowsByDataSource > 0 ? numberOfRowsByDataSource : 1)
    }
    
    fileprivate func selectedNearbyToMiddleRow(_ row: Int) {
        currentSelectedRow = row
        tableView.reloadData()
        tableView.contentInset = UIEdgeInsets.zero

        let indexOfSelectedRow = visibleIndexOfSelectedRow()
        tableView.setContentOffset(CGPoint(x: 0.0, y: CGFloat(indexOfSelectedRow) * rowHeight), animated: false)
        delegate?.pickerCoreView?(self, didSelectRow: currentSelectedRow)
        shouldSelectNearbyToMiddleRow = false
    }
    
    fileprivate func selectTappedRow(_ row: Int) {
        delegate?.pickerCoreView?(self, didTapRow: indexForRow(row))
        selectRow(row, animated: true)
    }

    fileprivate func turnPickerCoreViewOn() {
        tableView.isScrollEnabled = true
        setupSelectionViewsVisibility()
    }
    
    fileprivate func turnPickerCoreViewOff() {
        tableView.isScrollEnabled = false
        selectionOverlay.alpha = 0.0
        defaultSelectionIndicator.alpha = 0.0
        selectionImageView.alpha = 0.0
    }
    
    fileprivate func visibleIndexOfSelectedRow() -> Int {
        let middleMultiplier = scrollingStyle == .infinite ? (infinityRowsMultiplier / 2) : infinityRowsMultiplier
        let middleIndex = numberOfRowsByDataSource * middleMultiplier
        let indexForSelectedRow: Int
    
        if let _ = currentSelectedRow , scrollingStyle == .default && currentSelectedRow == 0 {
            indexForSelectedRow = 0
        } else if let _ = currentSelectedRow {
            indexForSelectedRow = middleIndex - (numberOfRowsByDataSource - currentSelectedRow)
        } else {
            let middleRow = Int(floor(Float(indexesByDataSource) / 2.0))
            indexForSelectedRow = middleIndex - (numberOfRowsByDataSource - middleRow)
        }
        
        return indexForSelectedRow
    }
    
    open func selectRow(_ row : Int, animated: Bool) {
        var finalRow = row
        
        if (scrollingStyle == .infinite && row <= numberOfRowsByDataSource) {
            let middleMultiplier = scrollingStyle == .infinite ? (infinityRowsMultiplier / 2) : infinityRowsMultiplier
            let middleIndex = numberOfRowsByDataSource * middleMultiplier
            finalRow = middleIndex - (numberOfRowsByDataSource - finalRow)
        }
        
        currentSelectedRow = finalRow
        
        delegate?.pickerCoreView?(self, didSelectRow: indexForRow(currentSelectedRow))
        
        tableView.setContentOffset(CGPoint(x: 0.0, y: CGFloat(currentSelectedRow) * rowHeight), animated: animated)
    }
    
    open func reloadPickerCoreView() {
        shouldSelectNearbyToMiddleRow = true
        tableView.reloadData()
    }
    
}

extension PickerCoreView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfRows = numberOfRowsByDataSource * infinityRowsMultiplier

        if shouldSelectNearbyToMiddleRow && numberOfRows > 0 {
            if isScrolling {
                let middleRow = Int(floor(Float(indexesByDataSource) / 2.0))
                selectedNearbyToMiddleRow(middleRow)
            } else {
                let rowToSelect = currentSelectedRow != nil ? currentSelectedRow : Int(floor(Float(indexesByDataSource) / 2.0))
                selectedNearbyToMiddleRow(rowToSelect!)
            }
        }

        if numberOfRows > 0 {
            turnPickerCoreViewOn()
        } else {
            turnPickerCoreViewOff()
        }

        return numberOfRows
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let indexOfSelectedRow = visibleIndexOfSelectedRow()
        
        let pickerCoreViewCell = tableView.dequeueReusableCell(withIdentifier: pickerCoreViewCellIdentifier, for: indexPath) as! SimplePickerTableViewCell
        
        let view = delegate?.pickerCoreView?(self, viewForRow: indexForRow((indexPath as NSIndexPath).row), highlighted: (indexPath as NSIndexPath).row == indexOfSelectedRow, reusingView: pickerCoreViewCell.customView)
        
        pickerCoreViewCell.selectionStyle = .none
        pickerCoreViewCell.backgroundColor = pickerCellBackgroundColor ?? UIColor.white
        
        if (view != nil) {
            var frame = view!.frame
            frame.origin.y = (indexPath as NSIndexPath).row == 0 ? (self.frame.height / 2) - (rowHeight / 2) : 0.0
            view!.frame = frame
            pickerCoreViewCell.customView = view
            pickerCoreViewCell.contentView.addSubview(pickerCoreViewCell.customView!)
            
        } else {
            let centerY = (indexPath as NSIndexPath).row == 0 ? (self.frame.height / 2) - (rowHeight / 2) : 0.0
            
            pickerCoreViewCell.titleLabel.frame = CGRect(x: 0.0, y: centerY, width: frame.width, height: rowHeight)
            
            pickerCoreViewCell.contentView.addSubview(pickerCoreViewCell.titleLabel)
            pickerCoreViewCell.titleLabel.backgroundColor = UIColor.clear
            pickerCoreViewCell.titleLabel.text = dataSource?.pickerCoreView(self, titleForRow: indexForRow((indexPath as NSIndexPath).row))
            
            delegate?.pickerCoreView?(self, styleForLabel: pickerCoreViewCell.titleLabel, highlighted: (indexPath as NSIndexPath).row == indexOfSelectedRow)
        }
        return pickerCoreViewCell
    }
    
}

extension PickerCoreView: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectTappedRow((indexPath as NSIndexPath).row)
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let numberOfRowsInPickerCoreView = dataSource!.pickerCoreViewNumberOfRows(self) * infinityRowsMultiplier
        if (indexPath as NSIndexPath).row == 0 {
            return (frame.height / 2) + (rowHeight / 2)
        } else if numberOfRowsInPickerCoreView > 0 && (indexPath as NSIndexPath).row == numberOfRowsInPickerCoreView - 1 {
            return (frame.height / 2) + (rowHeight / 2)
        }

        return rowHeight
    }
}

extension PickerCoreView: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrolling = true
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let partialRow = Float(targetContentOffset.pointee.y / rowHeight)
        var roundedRow = Int(lroundf(partialRow)) // Round the estimative to a row
        
        if roundedRow < 0 {
            roundedRow = 0
        } else {
            targetContentOffset.pointee.y = CGFloat(roundedRow) * rowHeight // Set the targetContentOffset (where the scrolling position will be when the animation ends) to a rounded value.
        }
        
        currentSelectedRow = indexForRow(roundedRow)
        
        delegate?.pickerCoreView?(self, didSelectRow: currentSelectedRow)
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // When the orientation changes during the scroll, is required to reset the picker to select the nearby to middle row.
        if orientationChanged {
            selectedNearbyToMiddleRow(currentSelectedRow)
            orientationChanged = false
        }
        
        isScrolling = false
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let partialRow = Float(scrollView.contentOffset.y / rowHeight)
        let roundedRow = Int(lroundf(partialRow))
        
        if let visibleRows = tableView.indexPathsForVisibleRows {
            for indexPath in visibleRows {
                if let cellToUnhighlight = tableView.cellForRow(at: indexPath) as? SimplePickerTableViewCell , (indexPath as NSIndexPath).row != roundedRow {
                    let _ = delegate?.pickerCoreView?(self, viewForRow: indexForRow((indexPath as NSIndexPath).row), highlighted: false, reusingView: cellToUnhighlight.customView)
                    delegate?.pickerCoreView?(self, styleForLabel: cellToUnhighlight.titleLabel, highlighted: false)
                }
            }
        }
        
        if let cellToHighlight = tableView.cellForRow(at: IndexPath(row: roundedRow, section: 0)) as? SimplePickerTableViewCell {
            let _ = delegate?.pickerCoreView?(self, viewForRow: indexForRow(roundedRow), highlighted: true, reusingView: cellToHighlight.customView)
            let _ = delegate?.pickerCoreView?(self, styleForLabel: cellToHighlight.titleLabel, highlighted: true)
        }
    }
    
}
