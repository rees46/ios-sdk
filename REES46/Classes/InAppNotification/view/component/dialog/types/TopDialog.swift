import UIKit

class TopDialog: BaseDialog {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    }
    
    override func setupContentView() {
        super.setupContentView()
        contentView.layer.cornerRadius = AppDimensions.Padding.medium
        contentView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }
    
    override func setContentContainerConstraints() {
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: imageContainer.isHidden ? contentView.safeTopAnchor: imageContainer.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        contentContainer.layoutMargins = UIEdgeInsets(top: AppDimensions.Padding.medium, left: AppDimensions.Padding.medium, bottom: AppDimensions.Padding.medium, right: AppDimensions.Padding.medium)
    }
   
    override func setContentViewConstraints() {
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    @objc override func dismissDialog() {
        UIView.animate(withDuration: AppDimensions.Animation.duration, animations: {
            self.view.frame.origin.y = -self.view.frame.height
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }
}
