import UIKit

public class FiltersPriceSliderThumbLayer: CALayer {
    var highlighted = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    public weak var rangeSlider: FiltersPriceSlider?
    
    public override func draw(in ctx: CGContext) {
        super.draw(in: ctx)
        if let slider = rangeSlider {
            let thumbFrame = bounds.insetBy(dx: 1.0, dy: 1.0)
            let cornerRadius = thumbFrame.height * slider.curvaceousness / 2.0
            let thumbPath = UIBezierPath(roundedRect: thumbFrame, cornerRadius: cornerRadius)
            
            let shadowColor = UIColor.gray
            ctx.setShadow(offset: CGSize(width: 0.0, height: 1.0), blur: 1.0, color: shadowColor.cgColor)
            ctx.setFillColor(slider.thumbTintColor.cgColor)
            ctx.addPath(thumbPath.cgPath)
            ctx.fillPath()
            
            ctx.setStrokeColor(shadowColor.cgColor)
            ctx.setLineWidth(0.5)
            ctx.addPath(thumbPath.cgPath)
            ctx.strokePath()
            
            if highlighted {
                ctx.setFillColor(UIColor(white: 0.0, alpha: 0.1).cgColor)
                ctx.addPath(thumbPath.cgPath)
                ctx.fillPath()
            }
         }
     }
}
