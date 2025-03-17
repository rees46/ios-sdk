import UIKit

class AlertDialog: BaseDialog {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.Background.alertDimmed
    }
    
    override func setupContentView() {
        super.setupContentView()
        contentView.layer.cornerRadius = AppDimensions.Padding.medium
    }
    
    override func setContentContainerConstraints() {
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: imageContainer.isHidden ? contentView.topAnchor : imageContainer.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    override func setContentViewConstraints() {
        NSLayoutConstraint.activate([
            contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppDimensions.Padding.large),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppDimensions.Padding.large)
        ])
    }
}
