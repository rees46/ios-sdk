import UIKit

@available(iOS 13.0, *)
open class FiltersCheckboxTree<T: FiltersCheckboxItem>: UIView {
    
    public var items: [T] = [] {
        didSet {
            reload()
        }
    }
    
    public private(set) var style: FiltersCheckboxTreeStyle<T> = FiltersCheckboxTreeStyle()

    public weak var delegate: FiltersCheckboxTreeDelegate?

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()
    
    private var nodes: [FiltersCheckboxNode<T>] = []

    public init(style: FiltersCheckboxTreeStyle<T> = FiltersCheckboxTreeStyle()) {
        self.style = style
        super.init(frame: .zero)
        
        setupView()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func reload() {
        stackView.arrangedSubviews.forEach{
            $0.removeFromSuperview()
        }

        nodes.removeAll()
        buildCheckboxTree()
        checkIfCollapseAvailable()
    }

    private func setupView() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func buildCheckboxTree() {
        for item in items {
            let node = FiltersCheckboxNode(item: item,
                                    depth: 0,
                                    parentNode: nil,
                                    style: style,
                                    delegate: self)
            nodes.append(node)

            node.forEachBranchNode { branchNode in
                stackView.addArrangedSubview(branchNode.itemView)
            }
        }
    }
    
    private func checkIfCollapseAvailable() {
        if !items.contains(where: { $0.type == .groupCheckbox }) {
            style.isCollapseAvailable = false
        }
    }
}

@available(iOS 13.0, *)
extension FiltersCheckboxTree: FiltersCheckboxItemDelegate {
    func collapseItemDidSelected(item: FiltersCheckboxItem) {
        delegate?.collapseSection(header: item, section: 0)
    }
    
    func checkboxItemDidSelected(item: FiltersCheckboxItem) {
        delegate?.checkboxItemDidSelected(item: item)
    }
}
