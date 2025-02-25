import UIKit
class DialogButtonClose: UIButton {
    
    private let crossLayer = CAShapeLayer()
    
    init() {
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        tintColor = .clear
        alpha = 0.7
        backgroundColor = UIColor(white: 0.5, alpha: 0.5)
        layer.cornerRadius = AppDimensions.Size.closeButtonCornerRadius
        
        let crossPath = UIBezierPath()
        let crossSize: CGFloat = AppDimensions.Size.crossSize
        let lineWidth: CGFloat = AppDimensions.Size.crossLineWidth
        
        let topOffset: CGFloat = AppDimensions.Offset.topOffset
        let leftOffset: CGFloat = AppDimensions.Offset.leftOffset
        
        crossPath.move(to: CGPoint(x: leftOffset, y: topOffset))
        crossPath.addLine(to: CGPoint(x: leftOffset + crossSize, y: topOffset + crossSize))
        crossPath.move(to: CGPoint(x: leftOffset + crossSize, y: topOffset))
        crossPath.addLine(to: CGPoint(x: leftOffset, y: topOffset + crossSize))
        
        crossLayer.path = crossPath.cgPath
        crossLayer.strokeColor = UIColor.gray.cgColor
        crossLayer.lineWidth = lineWidth
        layer.addSublayer(crossLayer)
    }
}
