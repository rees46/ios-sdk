import UIKit

class FiltersCheckboxNode<T: FiltersCheckboxItem> {

    private(set) var style: FiltersCheckboxTreeStyle<T>

    private(set) weak var parentNode: FiltersCheckboxNode?

    private(set) var item: T
    private(set) var depth: Int

    private(set) var itemView: FiltersCheckboxItemView<T>

    private(set) var children: [FiltersCheckboxNode] = []

    private(set) weak var delegate: FiltersCheckboxItemDelegate?

    init(item: T, depth: Int, parentNode: FiltersCheckboxNode?, style: FiltersCheckboxTreeStyle<T>, delegate: FiltersCheckboxItemDelegate?) {
        self.item = item
        self.depth = depth
        self.parentNode = parentNode
        self.style = style
        self.delegate = delegate

        itemView = style.getCheckboxItemView()
        itemView.setupView(item: item, level: depth)
        
        setupItemViewActions()
        
        generateChildNodes()
        
        updateItemViewVisibility()
    }

    func getRootNode() -> FiltersCheckboxNode {
        if let parentNode = parentNode {
            return parentNode.getRootNode()
        }
        return self
    }

    func forEachBranchNode(_ closure: (FiltersCheckboxNode) -> ()) {
        closure(self)
        forEachChildNode(closure)
    }

    func forEachChildNode(_ closure: (FiltersCheckboxNode) -> ()) {
        children.forEach { childNode in
            closure(childNode)
            childNode.forEachChildNode(closure)
        }
    }
    
    private func isHidden() -> Bool {
        if style.isCollapseAvailable == false {
            return false
        }

        if let parentNode = parentNode {
            if parentNode.item.isGroupCollapsed {
                return true
            } else {
                return parentNode.isHidden()
            }
        }
        return false
    }

    private func setupItemViewActions() {
        itemView.tapAction = { [weak self] in
            guard let self = self else {
                return
            }

            if self.item.selectionState == .mixed {
                if self.item.childrenCheckboxArray.filter({ item in
                    item.isEnabled
                }).contains(where: { item in
                    item.isSelected == false
                }) {
                    self.item.isSelected = true
                } else {
                    self.item.isSelected = false
                }
            } else {
                self.item.isSelected.toggle()
            }
            
            self.getRootNode().forEachBranchNode { node in
                node.itemView.updateSelectionImage(item: node.item)
            }
            
            self.delegate?.checkboxItemDidSelected(item: self.item)
        }

        itemView.collapseAction = { [weak self] in
            guard let self = self else {
                return
            }

            self.item.isGroupCollapsed.toggle()

            let collapseBlock = {
                self.itemView.transformGroupArrow(isCollapsed: self.item.isGroupCollapsed)

                self.forEachChildNode { node in
                    node.updateItemViewVisibility()
                }
            }

            if self.style.isCollapseAnimated {
                UIView.animate(withDuration: self.style.collapseAnimationDuration) {
                    collapseBlock()
                }
            } else {
                collapseBlock()
            }
            
            self.delegate?.collapseItemDidSelected(item: self.item)
        }
    }

    private func generateChildNodes() {
        for item in item.childrenCheckboxArray {
            let node = FiltersCheckboxNode(item: item as! T,
                                    depth: 0,
                                    parentNode: self,
                                    style: style,
                                    delegate: delegate)
            children.append(node)
        }
    }
    
    private func updateItemViewVisibility() {
        let isItemViewHidden = isHidden()

        if itemView.isHidden != isItemViewHidden {
            itemView.isHidden = isItemViewHidden
        }
        itemView.alpha = isItemViewHidden ? 0 : 1
    }
}
