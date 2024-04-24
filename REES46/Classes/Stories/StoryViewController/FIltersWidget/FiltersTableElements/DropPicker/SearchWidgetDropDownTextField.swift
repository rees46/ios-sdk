import UIKit

@MainActor
open class SearchWidgetDropDownTextField: UITextField, UIPickerViewDelegate, UIPickerViewDataSource {
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 1
    }
    
    public func numberOfComponents(in pickerCoreView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerCoreView(_ pickerCoreView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 0
    }
    
    nonisolated public static let optionalItemIndex: Int = -1

    open lazy var pickerCoreView: UIPickerView = {
        let view = UIPickerView()
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.showsSelectionIndicator = true
        view.delegate = self
        view.dataSource = self
        return view
    }()

    private lazy var dismissToolbar: UIToolbar = {
        let view = UIToolbar()
        view.isTranslucent = true
        view.sizeToFit()
        let buttonFlexible: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let buttonDone: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(resignFirstResponder))
        view.items = [buttonFlexible, buttonDone]
        return view
    }()

    internal let privateMenuButton: UIButton = UIButton()

    open var dropDownFont: UIFont?

    open var dropDownTextColor: UIColor?

    open var widthsForComponents: [CGFloat]?
    open var heightsForComponents: [CGFloat]?

    weak open var dropDownDelegate: SearchWidgetDropDownTextFieldDelegate?
    weak open override var delegate: UITextFieldDelegate? {
        didSet {
            dropDownDelegate = delegate as? SearchWidgetDropDownTextFieldDelegate
        }
    }

    open var dataSource: SearchWidgetDropDownTextFieldDataSource?

    open var dropDownMode: SearchWidgetDropDownMode = .list {
        didSet {
            switch dropDownMode {
            case .list, .multiList:
                inputView = pickerCoreView
                setSelectedRows(rows: selectedRows, animated: true)
            case .textField:
                inputView = nil
            }
            if #available(iOS 15.0, *) {
                reconfigureMenu()
            }
        }
    }

    private var privateOptionalItemText: String?
    private var privateOptionalItemTexts: [String?] = []

    private var privateIsOptionalDropDowns: [Bool] = []

    open var multiListSelectionFormatHandler: ((_ selectedItems: [String?], _ selectedIndexes: [Int]) -> String)? {
        didSet {
            if let handler = multiListSelectionFormatHandler {
                super.text = handler(selectedItems, selectedRows)
            } else {
                super.text = selectedItems.compactMap({ $0 }).joined(separator: ", ")
            }
        }
    }

    open var selectionFormatHandler: ((_ selectedItem: String?, _ selectedIndex: Int) -> String)? {
        didSet {
            if let handler = selectionFormatHandler {
                super.text = handler(selectedItem, selectedRow)
            } else {
                super.text = selectedItems.compactMap({ $0 }).joined(separator: ", ")
            }
        }
    }

    @available(*, deprecated, message: "SDK: Use 'selectedItem' instead", renamed: "selectedItem")
    open override var text: String? {
        didSet {
        }
    }

    @available(*, deprecated, message: "SDK: Use 'selectedItem' instead", renamed: "selectedItem")
    open override var attributedText: NSAttributedString? {
        didSet {
        }
    }

    open var multiItemList: [[String]] = [] {
        didSet {
            isOptionalDropDowns = privateIsOptionalDropDowns
            let selectedRows = selectedRows
            self.selectedRows = selectedRows
        }
    }

    open var multiItemListView: [[UIView?]] = [] {
        didSet {
            isOptionalDropDowns = privateIsOptionalDropDowns
            let selectedRows = selectedRows
            self.selectedRows = selectedRows
        }
    }

    open override var adjustsFontSizeToFitWidth: Bool {
        didSet {
            privateUpdateOptionsList()
        }
    }

    private var hasSetInitialIsOptional: Bool = false

    func dealloc() {
        pickerCoreView.delegate = nil
        pickerCoreView.dataSource = nil
        self.delegate = nil
        dataSource = nil
        privateOptionalItemText = nil
    }

    func initialize() {
        contentVerticalAlignment = .center
        contentHorizontalAlignment = .center

        do {
            let mode = dropDownMode
            dropDownMode = mode

            isOptionalDropDown = hasSetInitialIsOptional ? isOptionalDropDown : true
        }
        if #available(iOS 15.0, *) {
            initializeMenu()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        initialize()
    }

    @discardableResult
    open override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()

        for (index, selectedRow) in privatePickerSelectedRows where 0 <= selectedRow {
            pickerCoreView.selectRow(selectedRow, inComponent: index, animated: false)
        }
        return result
    }

    open override func caretRect(for position: UITextPosition) -> CGRect {
        if dropDownMode == .textField {
            return super.caretRect(for: position)
        } else {
            return .zero
        }
    }

    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(cut(_:)) || action == #selector(paste(_:)) {
            return false
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }

    internal var privatePickerSelectedRows: [Int: Int] = [:]

    open func privateUpdateOptionsList() {

        switch dropDownMode {
        case .list, .multiList:
            pickerCoreView.reloadAllComponents()
        case .textField:
            break
        }
    }
}

@MainActor
extension SearchWidgetDropDownTextField {
    @objc open var showDismissToolbar: Bool {
        get {
            return (inputAccessoryView == dismissToolbar)
        }
        set {
            inputAccessoryView = (newValue ? dismissToolbar : nil)
        }
    }
}

@MainActor
extension SearchWidgetDropDownTextField {
    @IBInspectable
    open var isOptionalDropDown: Bool {
        get { return privateIsOptionalDropDowns.first ?? true }
        set {
            isOptionalDropDowns = [newValue]
        }
    }

    @objc open var isOptionalDropDowns: [Bool] {
        get {
            return privateIsOptionalDropDowns
        }
        set {
            if !hasSetInitialIsOptional || privateIsOptionalDropDowns != newValue {

                let previousSelectedRows: [Int] = selectedRows

                privateIsOptionalDropDowns = newValue
                hasSetInitialIsOptional = true

                if dropDownMode == .list || dropDownMode == .multiList {
                    pickerCoreView.reloadAllComponents()
                    selectedRows = previousSelectedRows
                }
            }
        }
    }

    @IBInspectable
    open var optionalItemText: String? {
        get {
            if let privateOptionalItemText = privateOptionalItemText, !privateOptionalItemText.isEmpty {
                return privateOptionalItemText
            } else {
                return NSLocalizedString("Select", comment: "")
            }
        }
        set {
            privateOptionalItemText = newValue
            privateUpdateOptionsList()
        }
    }

    public var optionalItemTexts: [String?] {
        get {
            return privateOptionalItemTexts
        }
        set {
            privateOptionalItemTexts = newValue
            privateUpdateOptionsList()
        }
    }
}

@MainActor
extension SearchWidgetDropDownTextField {
    @objc open var itemList: [String] {
        get {
            multiItemList.first ?? []
        }
        set {
            multiItemList = [newValue]
        }
    }

    public var itemListView: [UIView?] {
        get {
            multiItemListView.first ?? []
        }
        set {
            multiItemListView = [newValue]
        }
    }
}

@MainActor
extension SearchWidgetDropDownTextField {

    @objc open var selectedRow: Int {
        get {
            var pickerCoreViewSelectedRow: Int = selectedRows.first ?? 0
            pickerCoreViewSelectedRow = max(pickerCoreViewSelectedRow, 0)
            return pickerCoreViewSelectedRow - (isOptionalDropDown ? 1 : 0)
        }
        set {
            selectedRows = [newValue]
        }
    }

    @objc open var selectedRows: [Int] {
        get {
            var selection: [Int] = []
            for index in multiItemList.indices {

                let isOptionalDropDown: Bool
                if index < isOptionalDropDowns.count {
                    isOptionalDropDown = isOptionalDropDowns[index]
                } else if let last = isOptionalDropDowns.last {
                    isOptionalDropDown = last
                } else {
                    isOptionalDropDown = true
                }

                var pickerCoreViewSelectedRow: Int = privatePickerSelectedRows[index] ?? -1
                pickerCoreViewSelectedRow = max(pickerCoreViewSelectedRow, 0)

                let finalSelection = pickerCoreViewSelectedRow - (isOptionalDropDown ? 1 : 0)
                selection.append(finalSelection)
            }
            return selection
        }
        set {
            setSelectedRows(rows: newValue, animated: false)
        }
    }

    @objc open func selectedRow(inSection section: Int) -> Int {
        privatePickerSelectedRows[section] ?? Self.optionalItemIndex
    }

    @objc open func setSelectedRow(row: Int, animated: Bool) {
        setSelectedRows(rows: [row], animated: animated)
    }

    @objc open func setSelectedRow(row: Int, inSection section: Int, animated: Bool) {
        var selectedRows = selectedRows
        selectedRows[section] = row
        setSelectedRows(rows: selectedRows, animated: animated)
    }

    @objc open func setSelectedRows(rows: [Int], animated: Bool) {

        var finalResults: [String?] = []
        for (index, row) in rows.enumerated() {

            let itemList: [String]

            if index < multiItemList.count {
                itemList = multiItemList[index]
            } else {
                itemList = []
            }

            let isOptionalDropDown: Bool
            if index < isOptionalDropDowns.count {
                isOptionalDropDown = isOptionalDropDowns[index]
            } else if let last = isOptionalDropDowns.last {
                isOptionalDropDown = last
            } else {
                isOptionalDropDown = true
            }

            if row == Self.optionalItemIndex {

                if !isOptionalDropDown, !itemList.isEmpty {
                    finalResults.append(itemList[0])
                } else {
                    finalResults.append(nil)
                }
            } else {
                if row < itemList.count {
                    finalResults.append(itemList[row])
                } else {
                    finalResults.append(nil)
                }
            }

            let pickerCoreViewRow: Int = row + (isOptionalDropDown ? 1 : 0)
            privatePickerSelectedRows[index] = pickerCoreViewRow
            if index < pickerCoreView.numberOfComponents {
                pickerCoreView.selectRow(pickerCoreViewRow, inComponent: index, animated: animated)
            }
        }

        if let multiListSelectionFormatHandler = multiListSelectionFormatHandler {
            super.text = multiListSelectionFormatHandler(finalResults, rows)
        } else if let selectionFormatHandler = selectionFormatHandler,
                  let selectedItem = finalResults.first,
                  let selectedRow = rows.first {
            super.text = selectionFormatHandler(selectedItem, selectedRow)
        } else {
            super.text = finalResults.compactMap({ $0 }).joined(separator: ", ")
        }
    }
}

@MainActor
extension SearchWidgetDropDownTextField {
    @objc open var selectedItem: String? {
        get {
            return selectedItems.first ?? nil
        }
        set {
            switch dropDownMode {
            case .multiList:
                if let newValue = newValue {
                    selectedItems = [newValue]
                } else {
                    selectedItems = multiItemList.map({ _ in nil })
                }
            case .list, .textField:
                selectedItems = [newValue]
            }
        }
    }

    public var selectedItems: [String?] {
        get {
            switch dropDownMode {
            case .list, .multiList:
                var finalSelection: [String?] = []
                for (index, selectedRow) in selectedRows.enumerated() {
                    if 0 <= selectedRow, index < multiItemList.count {
                        finalSelection.append(multiItemList[index][selectedRow])
                    } else {
                        finalSelection.append(nil)
                    }
                }
                return finalSelection
            case .textField:
                return [super.text]
            }
        }
        
        set {
            privateSetSelectedItems(selectedItems: newValue, animated: false, shouldNotifyDelegate: false)
        }
    }

    @objc open func setSelectedItem(selectedItem: String?, animated: Bool) {
        privateSetSelectedItems(selectedItems: [selectedItem], animated: animated, shouldNotifyDelegate: false)
    }

    public func setSelectedItems(selectedItems: [String?], animated: Bool) {
        privateSetSelectedItems(selectedItems: selectedItems, animated: animated, shouldNotifyDelegate: false)
    }
}

@MainActor
internal extension SearchWidgetDropDownTextField {
    func privateSetSelectedItems(selectedItems: [String?], animated: Bool, shouldNotifyDelegate: Bool) {
        switch dropDownMode {
        case .list, .multiList:

            var finalIndexes: [Int] = []
            var finalSelection: [String?] = []

            for (index, selectedItem) in selectedItems.enumerated() {

                if let selectedItem = selectedItem,
                   index < multiItemList.count,
                   let index = multiItemList[index].firstIndex(of: selectedItem) {
                    finalIndexes.append(index)
                    finalSelection.append(selectedItem)

                } else {

                    let isOptionalDropDown: Bool
                    if index < isOptionalDropDowns.count {
                        isOptionalDropDown = isOptionalDropDowns[index]
                    } else if let last = isOptionalDropDowns.last {
                        isOptionalDropDown = last
                    } else {
                        isOptionalDropDown = true
                    }

                    let selectedIndex = isOptionalDropDown ? Self.optionalItemIndex : 0
                    finalIndexes.append(selectedIndex)
                    finalSelection.append(nil)
                }
            }

            setSelectedRows(rows: finalIndexes, animated: animated)

            if shouldNotifyDelegate {
                if dropDownMode == .multiList {
                    dropDownDelegate?.textField(textField: self, didSelectItems: finalSelection)
                } else if let selectedItem = finalSelection.first {
                    dropDownDelegate?.textField(textField: self, didSelectItem: selectedItem)
                }
            }

        case .textField:
            super.text = selectedItems.compactMap({ $0 }).joined(separator: ", ")
        }
    }
}
