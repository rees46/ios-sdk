import UIKit

class SearchFilterCheckBoxView: UIView{
    
    private let colorLabel: UILabel = {
        let label = UILabel()
        label.text = "Color"
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.black
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView(){
        addSubview(colorLabel)
        setupColorLabelConstraints()
    }
    
    private func setupColorLabelConstraints() {
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(
            [
                colorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                colorLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
                colorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            ]
        )
    }
    
}
