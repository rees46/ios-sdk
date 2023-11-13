import Foundation
import UIKit

public enum StarFillMode: Int {
    case full = 0
    case half = 1
    case precise = 2
}

struct RecommendStarLayer {
    static func create(_ starPoints: [CGPoint], size: Double, lineWidth: Double, fillColor: UIColor, strokeColor: UIColor) -> CALayer {
        let containerLayer = createContainerLayer(size)
        let path = createStarPath(starPoints, size: size, lineWidth: lineWidth)
      
        let shapeLayer = createShapeLayer(path.cgPath, lineWidth: lineWidth, fillColor: fillColor, strokeColor: strokeColor, size: size)
        containerLayer.addSublayer(shapeLayer)
    
        return containerLayer
    }

    static func create(image: UIImage, size: Double) -> CALayer {
        let containerLayer = createContainerLayer(size)
        let imageLayer = createContainerLayer(size)

        containerLayer.addSublayer(imageLayer)
        imageLayer.contents = image.cgImage
        imageLayer.contentsGravity = CALayerContentsGravity.resizeAspect
    
        return containerLayer
    }

    static func createShapeLayer(_ path: CGPath, lineWidth: Double, fillColor: UIColor, strokeColor: UIColor, size: Double) -> CALayer {
        let layer = CAShapeLayer()
        layer.anchorPoint = CGPoint()
        layer.contentsScale = UIScreen.main.scale
        layer.strokeColor = strokeColor.cgColor
        layer.fillColor = fillColor.cgColor
        layer.lineWidth = CGFloat(lineWidth)
        layer.bounds.size = CGSize(width: size, height: size)
        layer.masksToBounds = true
        layer.path = path
        layer.isOpaque = true
        return layer
    }
    
    static func createContainerLayer(_ size: Double) -> CALayer {
        let layer = CALayer()
        layer.contentsScale = UIScreen.main.scale
        layer.anchorPoint = CGPoint()
        layer.masksToBounds = true
        layer.bounds.size = CGSize(width: size, height: size)
        layer.isOpaque = true
        return layer
    }

    static func createStarPath(_ starPoints: [CGPoint], size: Double, lineWidth: Double) -> UIBezierPath {
    
        let lineWidthLocal = lineWidth + ceil(lineWidth * 0.3)
        let sizeWithoutLineWidth = size - lineWidthLocal * 2
        
        let points = scaleStar(starPoints, factor: sizeWithoutLineWidth / 100,
                               lineWidth: lineWidthLocal)
        
        let path = UIBezierPath()
        path.move(to: points[0])
        let remainingPoints = Array(points[1..<points.count])
        
        for point in remainingPoints {
            path.addLine(to: point)
        }
        
        path.close()
        return path
    }
  
    static func scaleStar(_ starPoints: [CGPoint], factor: Double, lineWidth: Double) -> [CGPoint] {
        return starPoints.map { point in
          return CGPoint(
            x: point.x * CGFloat(factor) + CGFloat(lineWidth),
            y: point.y * CGFloat(factor) + CGFloat(lineWidth)
          )
        }
    }
}


struct RecommendationsStarsAccessibility {

    static func update(_ view: UIView, rating: Double, text: String?, starsSetupSettings: RecommendationsStarsSettings) {
        view.isAccessibilityElement = true
        
        view.accessibilityTraits = starsSetupSettings.reloadOnUserTouch ? UIAccessibilityTraits.adjustable : UIAccessibilityTraits.none
        
        var accessibilityLabel = "Rating"
        
        if let text = text, text != "" {
          accessibilityLabel += " \(text)"
        }
        
        view.accessibilityLabel = accessibilityLabel
        
        view.accessibilityValue = accessibilityValue(view, rating: rating, starsSetupSettings: starsSetupSettings)
    }
  
    static func accessibilityValue(_ view: UIView, rating: Double, starsSetupSettings: RecommendationsStarsSettings) -> String {
        let accessibilityRating = RecommendationsStarsRating.showRatingStFromPreciseStRating(rating, fillMode: starsSetupSettings.fillMode, summaryRecommendationsStars: starsSetupSettings.summaryRecommendationsStars)
        
        let isInteger = (accessibilityRating * 10).truncatingRemainder(dividingBy: 10) == 0
        
        if isInteger {
            return "\(Int(accessibilityRating))"
        } else {
            let roundedToFirstDecimalPlace = Double( round(10 * accessibilityRating) / 10 )
            return "\(roundedToFirstDecimalPlace)"
        }
    }
  
    static func accessibilityIncrement(_ rating: Double, starsSetupSettings: RecommendationsStarsSettings) -> Double {
        var increment: Double = 0
          
        switch starsSetupSettings.fillMode {
        case .full:
            increment = ceil(rating) - rating
            if increment == 0 {
                increment = 1
            }

        case .half, .precise:
            increment = (ceil(rating * 2) - rating * 2) / 2
            if increment == 0 {
                increment = 0.5
            }
        }
        
        if rating >= Double(starsSetupSettings.summaryRecommendationsStars) { increment = 0 }

        let roundedToFirstDecimalPlace = Double( round(10 * increment) / 10 )
        return roundedToFirstDecimalPlace
    }
  
    static func accessibilityDecrement(_ rating: Double, starsSetupSettings: RecommendationsStarsSettings) -> Double {
        var increment: Double = 0
        
        switch starsSetupSettings.fillMode {
        case .full:
            increment = rating - floor(rating)
            if increment == 0 {
                increment = 1
            }
          
        case .half, .precise:
            increment = (rating * 2 - floor(rating * 2)) / 2
            if increment == 0 {
                increment = 0.5
            }
        }
        
        if rating <= starsSetupSettings.minStTchRating { increment = 0 }

        let roundedToFirstDecimalPlace = Double( round(10 * increment) / 10 )
        return roundedToFirstDecimalPlace
    }
}


class RecommendationsStarsText {
    class func position(_ layer: CALayer, starsSize: CGSize, textMargin: Double) {
        layer.position.x = starsSize.width + CGFloat(textMargin)
        let yOffset = (starsSize.height - layer.bounds.height) / 2
        layer.position.y = yOffset
    }
}


struct RecommendationsStarsDefaultSettings {
    
    init() {}
    
    static let sColor = SdkConfiguration.recommendations.widgetStarsColor.hexToRGB()
    static let defaultStarsColor = UIColor(red: sColor.red, green: sColor.green, blue: sColor.blue, alpha: 1) // UIColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1)
    
    static let emptyBorderColor = defaultStarsColor
    static let emptyBorderWidth: Double = 4 / Double(UIScreen.main.scale)
    
    static let filledBorderColor = defaultStarsColor
    static let filledBorderWidth: Double = 1 / Double(UIScreen.main.scale)
    
    static let emptyColor = UIColor.clear
    static let filledColor = defaultStarsColor

    static let fillMode = StarFillMode.full
    static let rating: Double = 2.718281828
    static let rateStMargin: Double = 2
      
    static let starPoints: [CGPoint] = [
        CGPoint(x: 49.5,  y: 0.0),
        CGPoint(x: 60.5,  y: 35.0),
        CGPoint(x: 99.0, y: 35.0),
        CGPoint(x: 67.5,  y: 58.0),
        CGPoint(x: 78.5,  y: 92.0),
        CGPoint(x: 49.5,    y: 71.0),
        CGPoint(x: 20.5,  y: 92.0),
        CGPoint(x: 31.5,  y: 58.0),
        CGPoint(x: 0.0,   y: 35.0),
        CGPoint(x: 38.5,  y: 35.0)
    ]

    static var starSize: Double = 21
    static let summaryRecommendationsStars = 5
    static let textColor = UIColor(red: 127/255, green: 127/255, blue: 127/255, alpha: 1)
    static let textFont = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.footnote)
    static let textMargin: Double = 5
    static var textSize: Double {
        get {
            return Double(textFont.pointSize)
        }
    }
 
    static let minStTchRating: Double = 1
    static let passUserTchToSuperview = true
    static let reloadOnUserTouch = true
}


class RecommendationsStarsSize {
    class func calculateSizeToFitLayers(_ layers: [CALayer]) -> CGSize {
        var size = CGSize()
        
        for layer in layers {
            if layer.frame.maxX > size.width {
                size.width = layer.frame.maxX
            }
            if layer.frame.maxY > size.height {
                size.height = layer.frame.maxY
            }
        }
        
        return size
    }
}


class RecommendationsStarsLayers {
    class func createRecommendstarViewLayer(_ rating: Double, starsSetupSettings: RecommendationsStarsSettings, isactionRightStarsToLeft: Bool) -> [CALayer] {

        var ratingRetranslator = RecommendationsStarsRating.numberOfFilledRateStars(rating,  totalNumberOfStars: starsSetupSettings.summaryRecommendationsStars)
        var starViewLayer = [CALayer]()

        for _ in (0..<starsSetupSettings.summaryRecommendationsStars) {
              let fillLevel = RecommendationsStarsRating.rateStFillLevel(ratingRemainder: ratingRetranslator,
                fillMode: starsSetupSettings.fillMode)
              
              let starLayer = createCompositeRecommendStarLayer(fillLevel, starsSetupSettings: starsSetupSettings, isactionRightStarsToLeft: isactionRightStarsToLeft)
              starViewLayer.append(starLayer)
              ratingRetranslator -= 1
        }
    
        if isactionRightStarsToLeft { starViewLayer.reverse() }
        poseRecommendstarViewLayer(starViewLayer, rateStMargin: starsSetupSettings.rateStMargin)
        
        return starViewLayer
    }

    class func createCompositeRecommendStarLayer(_ rateStFillLevel: Double, starsSetupSettings: RecommendationsStarsSettings, isactionRightStarsToLeft: Bool) -> CALayer {

        if rateStFillLevel >= 1 {
            return createRecommendStarLayer(true, starsSetupSettings: starsSetupSettings)
        }

        if rateStFillLevel == 0 {
            return createRecommendStarLayer(false, starsSetupSettings: starsSetupSettings)
        }

        return createPartialStar(rateStFillLevel, starsSetupSettings: starsSetupSettings, isactionRightStarsToLeft: isactionRightStarsToLeft)
    }

    class func createPartialStar(_ rateStFillLevel: Double, starsSetupSettings: RecommendationsStarsSettings, isactionRightStarsToLeft: Bool) -> CALayer {
        let filledStar = createRecommendStarLayer(true, starsSetupSettings: starsSetupSettings)
        let emptyStar = createRecommendStarLayer(false, starsSetupSettings: starsSetupSettings)

        let parentLayer = CALayer()
        parentLayer.contentsScale = UIScreen.main.scale
        parentLayer.bounds = CGRect(origin: CGPoint(), size: filledStar.bounds.size)
        parentLayer.anchorPoint = CGPoint()
        parentLayer.addSublayer(emptyStar)
        parentLayer.addSublayer(filledStar)
        
        if isactionRightStarsToLeft {
            let rotationScope = CATransform3DMakeRotation(CGFloat(Double.pi), 0, 1, 0)
            filledStar.transform = CATransform3DTranslate(rotationScope, -filledStar.bounds.size.width, 0, 0)
        }
        
        filledStar.bounds.size.width *= CGFloat(rateStFillLevel)

        return parentLayer
    }

    private class func createRecommendStarLayer(_ isFilled: Bool, starsSetupSettings: RecommendationsStarsSettings) -> CALayer {
        if let image = isFilled ? starsSetupSettings.filledImage : starsSetupSettings.emptyImage {
            return RecommendStarLayer.create(image: image, size: starsSetupSettings.starSize)
        }
        
        let fillColor = isFilled ? starsSetupSettings.filledColor : starsSetupSettings.emptyColor
        let strokeColor = isFilled ? starsSetupSettings.filledBorderColor : starsSetupSettings.emptyBorderColor

        return RecommendStarLayer.create(starsSetupSettings.starPoints,
                                         size: starsSetupSettings.starSize,
                                         lineWidth: isFilled ? starsSetupSettings.filledBorderWidth : starsSetupSettings.emptyBorderWidth,
                                         fillColor: fillColor,
                                         strokeColor: strokeColor)
    }

    class func poseRecommendstarViewLayer(_ layers: [CALayer], rateStMargin: Double) {
        var positionX:CGFloat = 0

        for layer in layers {
            layer.position.x = positionX
            positionX += layer.bounds.width + CGFloat(rateStMargin)
        }
    }
}


class RecommendationsStarsLayerHelper {
    class func crStarsTextLayer(_ text: String, font: UIFont, color: UIColor) -> CATextLayer {
        let size = NSString(string: text).size(withAttributes: [NSAttributedString.Key.font: font])
        
        let layer = CATextLayer()
        layer.bounds = CGRect(origin: CGPoint(), size: size)
        layer.anchorPoint = CGPoint()
        
        layer.string = text
        layer.font = CGFont(font.fontName as CFString)
        layer.fontSize = font.pointSize
        layer.foregroundColor = color.cgColor
        layer.contentsScale = UIScreen.main.scale
        
        return layer
    }
}


struct RecommendationsStarsTouch {
    static func didUserTchRating(_ position: CGFloat, starsSetupSettings: RecommendationsStarsSettings) -> Double {
        var rating = starRecommendationsPreRating(position: Double(position),
                                                  numberOfStars: starsSetupSettings.summaryRecommendationsStars,
                                                  starSize: starsSetupSettings.starSize,
                                                  rateStMargin: starsSetupSettings.rateStMargin)
        
        if starsSetupSettings.fillMode == .half {
            rating += 0.20
        }
        
        if starsSetupSettings.fillMode == .full {
            rating += 0.45
        }
        
        rating = RecommendationsStarsRating.showRatingStFromPreciseStRating(rating, fillMode: starsSetupSettings.fillMode, summaryRecommendationsStars: starsSetupSettings.summaryRecommendationsStars)
        
        rating = max(starsSetupSettings.minStTchRating, rating)
            
        return rating
    }
  
  static func starRecommendationsPreRating(position: Double, numberOfStars: Int, starSize: Double, rateStMargin: Double) -> Double {
        if position < 0 {
            return 0
        }
        var positionRemainder = position;
        
        var rating: Double = Double(Int(position / (starSize + rateStMargin)))
        
        if Int(rating) > numberOfStars { return Double(numberOfStars) }
        
        positionRemainder -= rating * (starSize + rateStMargin)
        
        if positionRemainder > starSize {
            rating += 1
        } else {
            rating += positionRemainder / starSize
        }
        
        return rating
    }
}


struct RecommendationsStarsRating {
    static func rateStFillLevel(ratingRemainder: Double, fillMode: StarFillMode) -> Double {
        var result = ratingRemainder
        
        if result > 1 {
            result = 1
        }
        
        if result < 0 {
            result = 0
        }
        
        return roundFillLevel(result, fillMode: fillMode)
    }
  
    static func roundFillLevel(_ rateStFillLevel: Double, fillMode: StarFillMode) -> Double {
        switch fillMode {
        case .full:
            return Double(round(rateStFillLevel))
        case .half:
            return Double(round(rateStFillLevel * 2) / 2)
        case .precise :
            return rateStFillLevel
        }
    }
  
    static func showRatingStFromPreciseStRating(_ starRecommendationsPreRating: Double, fillMode: StarFillMode, summaryRecommendationsStars: Int) -> Double {
        let starFloorNumber = floor(starRecommendationsPreRating)
        let singleStarRemainder = starRecommendationsPreRating - starFloorNumber
        
        var displayedRating = starFloorNumber + rateStFillLevel(
          ratingRemainder: singleStarRemainder, fillMode: fillMode)
          
        displayedRating = min(Double(summaryRecommendationsStars), displayedRating)
        displayedRating = max(0, displayedRating)
        
        return displayedRating
    }
  
    static func numberOfFilledRateStars(_ rating: Double, totalNumberOfStars: Int) -> Double {
        if rating > Double(totalNumberOfStars) { return Double(totalNumberOfStars) }
        if rating < 0 {
            return 0
        }
    
        return rating
    }
}


public struct RecommendationsStarsSettings {

    public static var `default`: RecommendationsStarsSettings {
        return RecommendationsStarsSettings()
    }

    public init() {}
  
    public var emptyBorderColor = RecommendationsStarsDefaultSettings.emptyBorderColor
  
    public var emptyBorderWidth: Double = RecommendationsStarsDefaultSettings.emptyBorderWidth
  
    public var filledBorderColor = RecommendationsStarsDefaultSettings.filledBorderColor
  
    public var filledBorderWidth: Double = RecommendationsStarsDefaultSettings.filledBorderWidth

    public var emptyColor = RecommendationsStarsDefaultSettings.emptyColor
  
    public var filledColor = RecommendationsStarsDefaultSettings.filledColor
  
    public var fillMode = RecommendationsStarsDefaultSettings.fillMode
  
    public var rateStMargin: Double = RecommendationsStarsDefaultSettings.rateStMargin
  
    public var starPoints: [CGPoint] = RecommendationsStarsDefaultSettings.starPoints
  
    public var starSize: Double = RecommendationsStarsDefaultSettings.starSize
  
    public var summaryRecommendationsStars = RecommendationsStarsDefaultSettings.summaryRecommendationsStars
  
    public var filledImage: UIImage? = nil
    
    public var emptyImage: UIImage? = nil
    
    public var textColor = RecommendationsStarsDefaultSettings.textColor
  
    public var textFont = RecommendationsStarsDefaultSettings.textFont
  
    public var textMargin: Double = RecommendationsStarsDefaultSettings.textMargin
  
    public var minStTchRating: Double = RecommendationsStarsDefaultSettings.minStTchRating
  
    public var passUserTchToSuperview = RecommendationsStarsDefaultSettings.passUserTchToSuperview
  
    public var reloadOnUserTouch = RecommendationsStarsDefaultSettings.reloadOnUserTouch
}


struct RecommendationsStarsTouchTarget {
    static func optimize(_ bounds: CGRect) -> CGRect {
        let recommendedHitSize: CGFloat = 44
        
        var hitWidthIncrease:CGFloat = recommendedHitSize - bounds.width
        var hitHeightIncrease:CGFloat = recommendedHitSize - bounds.height
        
        if hitWidthIncrease < 0 {
            hitWidthIncrease = 0
        }
        if hitHeightIncrease < 0 {
            hitHeightIncrease = 0
        }
        
        let extendedBounds: CGRect = bounds.insetBy(dx: -hitWidthIncrease / 2, dy: -hitHeightIncrease / 2)
        
        return extendedBounds
    }
}


struct actionRightStarsToLeft {
    static func isactionRightStarsToLeft(_ view: UIView) -> Bool {
        return false
    }
}


@IBDesignable open class RecommendationsStarsView: UIView {
    
    @IBInspectable open var rating: Double = RecommendationsStarsDefaultSettings.rating {
        didSet {
            if oldValue != rating {
                update()
            }
        }
    }
    
    @IBInspectable open var text: String? {
        didSet {
            if oldValue != text {
                update()
            }
        }
    }
    
    open var starsSetupSettings: RecommendationsStarsSettings = .default {
        didSet {
            update()
        }
    }
    
    private var viewSize = CGSize()
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        
        update()
    }
    
    public convenience init(starsSetupSettings: RecommendationsStarsSettings = .default) {
        self.init(frame: .zero, starsSetupSettings: starsSetupSettings)
    }
    
    override public convenience init(frame: CGRect) {
        self.init(frame: frame, starsSetupSettings: .default)
    }
    
    public init(frame: CGRect, starsSetupSettings: RecommendationsStarsSettings) {
        super.init(frame: frame)
        self.starsSetupSettings = starsSetupSettings
        
        update()
        
        improvePerformance()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        improvePerformance()
    }
    
    private func improvePerformance() {
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
        
        isOpaque = true
    }
    
    open func update() {
        var layers = RecommendationsStarsLayers.createRecommendstarViewLayer(
            rating,
            starsSetupSettings: starsSetupSettings,
            isactionRightStarsToLeft: actionRightStarsToLeft.isactionRightStarsToLeft(self)
        )
        if let text = text {
            let textLayer = crStarsTextLayer(text, layers: layers)
            layers = addTextLayer(textLayer: textLayer, layers: layers)
        }
        
        layer.sublayers = layers
        updateSize(layers)
        updateAccessibility()
    }
    
    private func crStarsTextLayer(_ text: String, layers: [CALayer]) -> CALayer {
        let textLayer = RecommendationsStarsLayerHelper.crStarsTextLayer(text, font: starsSetupSettings.textFont, color: starsSetupSettings.textColor)
        
        let starsSize = RecommendationsStarsSize.calculateSizeToFitLayers(layers)
        
        if actionRightStarsToLeft.isactionRightStarsToLeft(self) {
            RecommendationsStarsText.position(textLayer, starsSize: CGSize(width: 0, height: starsSize.height), textMargin: 0)
        } else {
            RecommendationsStarsText.position(textLayer, starsSize: starsSize, textMargin: starsSetupSettings.textMargin)
        }
        
        layer.addSublayer(textLayer)
        return textLayer
    }
    
    private func addTextLayer(textLayer: CALayer, layers: [CALayer]) -> [CALayer] {
        var allLayers = layers
        if actionRightStarsToLeft.isactionRightStarsToLeft(self) {
            for starLayer in layers {
                starLayer.position.x += textLayer.bounds.width + CGFloat(starsSetupSettings.textMargin);
            }
            
            allLayers.insert(textLayer, at: 0)
        } else {
            allLayers.append(textLayer)
        }
        
        return allLayers
    }
    
    private func updateSize(_ layers: [CALayer]) {
        viewSize = RecommendationsStarsSize.calculateSizeToFitLayers(layers)
        invalidateIntrinsicContentSize()
        
        frame.size = intrinsicContentSize
    }
    
    override open var intrinsicContentSize:CGSize {
        return viewSize
    }
    
    open func prepareForReuse() {
        previousRatingForDidTouchCallback = -123.192
    }
    
    private func updateAccessibility() {
        RecommendationsStarsAccessibility.update(self, rating: rating, text: text, starsSetupSettings: starsSetupSettings)
    }
    
    open override func accessibilityIncrement() {
        super.accessibilityIncrement()
        
        rating += RecommendationsStarsAccessibility.accessibilityIncrement(rating, starsSetupSettings: starsSetupSettings)
        didTouchRecommendationsStars?(rating)
        didFinishTouchingRecommendationsStars?(rating)
    }
    
    open override func accessibilityDecrement() {
        super.accessibilityDecrement()
        
        rating -= RecommendationsStarsAccessibility.accessibilityDecrement(rating, starsSetupSettings: starsSetupSettings)
        didTouchRecommendationsStars?(rating)
        didFinishTouchingRecommendationsStars?(rating)
    }
    
    open var didTouchRecommendationsStars: ((Double)->())?
    
    open var didFinishTouchingRecommendationsStars: ((Double)->())?
    
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if starsSetupSettings.passUserTchToSuperview { super.touchesBegan(touches, with: event) }
        guard let location = touchLocationFromBeginningOfRating(touches) else {
            return
        }
        onDidTouch(location)
    }
    
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if starsSetupSettings.passUserTchToSuperview { super.touchesMoved(touches, with: event) }
        guard let location = touchLocationFromBeginningOfRating(touches) else {
            return
        }
        onDidTouch(location)
    }
    
    func touchLocationFromBeginningOfRating(_ touches: Set<UITouch>) -> CGFloat? {
        guard let touch = touches.first else {
            return nil
        }
        var location = touch.location(in: self).x
        
        if actionRightStarsToLeft.isactionRightStarsToLeft(self) { location = bounds.width - location }
        return location
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if starsSetupSettings.passUserTchToSuperview {
            super.touchesEnded(touches, with: event)
        }
        didFinishTouchingRecommendationsStars?(rating)
    }
    
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if starsSetupSettings.passUserTchToSuperview {
            super.touchesCancelled(touches, with: event)
        }
        didFinishTouchingRecommendationsStars?(rating)
    }
    
    func onDidTouch(_ locationX: CGFloat) {
        let calculatedTouchRating = RecommendationsStarsTouch.didUserTchRating(locationX, starsSetupSettings: starsSetupSettings)
        
        if starsSetupSettings.reloadOnUserTouch {
            rating = calculatedTouchRating
        }
        
        if calculatedTouchRating == previousRatingForDidTouchCallback {
            return
        }
        
        didTouchRecommendationsStars?(calculatedTouchRating)
        previousRatingForDidTouchCallback = calculatedTouchRating
    }
    
    private var previousRatingForDidTouchCallback: Double = -123.192
    
    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let oprimizedBounds = RecommendationsStarsTouchTarget.optimize(bounds)
        return oprimizedBounds.contains(point)
    }
}
