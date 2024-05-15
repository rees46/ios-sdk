import Foundation
import UIKit

open class FiltersPriceSliderTrackerLayer: CALayer {
    
    public weak var rangeSlider: FiltersPriceSlider?
    
    public override func draw(in ctx: CGContext) {
        super.draw(in: ctx)
        if let slider = rangeSlider {
            
            let cornerRadius = bounds.height * slider.curvaceousness / 2.0
            let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
            ctx.addPath(path.cgPath)
            
            ctx.setFillColor(slider.trackTintColor.cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
            
            ctx.setFillColor(slider.trackHighlightTintColor.cgColor)
            let lowerValuePosition = CGFloat(slider.positionForValue(slider.lowerValue))
            let upperValuePosition = CGFloat(slider.positionForValue(slider.upperValue))
            let rect = CGRect(x: lowerValuePosition, y: 0.0, width: upperValuePosition - lowerValuePosition, height: bounds.height)
            ctx.fill(rect)
        }
    }
}
