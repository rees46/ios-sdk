import UIKit

open class UISdkWrapLabel: UILabel {

    @IBInspectable
    public var maximumFontSizeBySdk: CGFloat = 40

    @IBInspectable
    public var minimumFontSizeBySdk: CGFloat = 1

    public convenience init() {
        self.init(frame: CGRect.zero)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        self.commonInit()
    }

    open func commonInit() {
        self.adjustsFontSizeToFitWidth = false
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        self.adjustFontSize()
        self.setMinimumScaleFactorBySdk()
    }

    private func adjustFontSize() {
        if self.maximumFontSizeBySdk < self.minimumFontSizeBySdk {
            print("SDK: Warning 'maximumFontSizeBySdk' should be greater 'minimumFontSizeBySdk'")
            self.minimumFontSizeBySdk = self.maximumFontSizeBySdk
        }

        let additionalLbl = self.getAdditionalLbl()

        var adjustmentSdkResultFontSize: CGFloat = self.minimumFontSizeBySdk
        var currentMax: Int = Int(self.maximumFontSizeBySdk)
        var currentMin: Int = Int(self.minimumFontSizeBySdk)

        repeat {
            var middleValue = currentMin + ((currentMax - currentMin) / 2)

            additionalLbl.font = additionalLbl.font.withSize(CGFloat(middleValue))
            additionalLbl.bounds = CGRect.zero
            additionalLbl.sizeToFit()

            if additionalLbl.bounds.width > self.bounds.width {

                if currentMax == middleValue {
                    middleValue -= 1
                }

                currentMax = middleValue
            } else {
                adjustmentSdkResultFontSize = CGFloat(middleValue)

                if currentMin == middleValue {
                    middleValue += 1
                }

                currentMin = middleValue
            }

        } while currentMin <= currentMax

        self.font = self.font.withSize(adjustmentSdkResultFontSize)
    }

    private func getAdditionalLbl() -> UILabel {

        let additionalLbl = UILabel()
        additionalLbl.font = self.font
        additionalLbl.numberOfLines = 0
        additionalLbl.text = self.text?.replacingOccurrences(of: " ", with: "\n")
        return additionalLbl
    }

    private func setMinimumScaleFactorBySdk() {
        let currentFontSize = self.font.pointSize
        self.minimumScaleFactor = self.minimumFontSizeBySdk / currentFontSize
    }
}
