import UIKit

class BottomDialog: BaseDialog {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DialogStyle.applyBackgroundStyle(to: view)
    }
    
    override func setupContentView() {
        super.setupContentView()
        DialogStyle.applyBottomDialogStyle(to: contentView)
    }
    
    override func setContentContainerConstraints() {
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: imageContainer.isHidden ? contentView.topAnchor : imageContainer.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor) 
        ])
    }
    
    override func setContentViewConstraints() {
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
