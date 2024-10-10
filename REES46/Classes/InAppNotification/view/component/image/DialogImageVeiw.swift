import Foundation

class DialogImageVeiw: UIImageView {
    
    init() {
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        contentMode = .scaleAspectFill
        clipsToBounds = true
    }
}
