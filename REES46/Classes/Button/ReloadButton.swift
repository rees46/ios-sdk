import UIKit

class ReloadButton: UIButton {
    init() {
        super.init(frame: .zero)
        setToDefault()
    }
    
    func configReloadButton() {
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        setImage(UIImage(named: "iconReload", in: frameworkBundle, compatibleWith: nil), for: .normal)
        addTarget(self, action: #selector(didTapReloadButton), for: .touchUpInside)
    }
    
    private func setToDefault() {
        self.layer.masksToBounds = true
    }
    
    @objc public func didTapReloadButton() {
        print("didTapReloadButton")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setToDefault()
    }
}
