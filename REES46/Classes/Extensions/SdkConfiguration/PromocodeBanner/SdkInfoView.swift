import QuartzCore
import UIKit

@available(iOSApplicationExtension, unavailable)
public class SdkInfoView: UIView {
    public enum TextAlignment {
        case left
        case center
        case right
    }

    public enum Position {
        case top
        case bottom
    }

    override public var bounds: CGRect {
        didSet {
            setupShadow()
        }
    }

    private let position: Position
    private var initialTransform: CGAffineTransform {
        switch position {
        case .top:
            return CGAffineTransform(translationX: 0, y: -100)
        case .bottom:
            return CGAffineTransform(translationX: 0, y: 100)
        }
    }
    private let hStack: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        return stackView
    }()

    private lazy var vStack: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = vStackAlignment
        return stackView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        if #available(iOS 13.0, *) {
            label.textColor = .label
        } else {
            label.textColor = .black
        }
        return label
    }()

    private var viewBackgroundColor: UIColor? {
        if #available(iOS 12.0, *) {
            return traitCollection.userInterfaceStyle == .dark ? darkBackgroundColor : lightBackgroundColor
        } else {
            return lightBackgroundColor
        }
    }

    private var vStackAlignment: UIStackView.Alignment {
        switch textAlignment {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }

    private var onTap: (() -> ())?

    public var autoHide = true
    public var displayTime: TimeInterval = 2
    public var showAnimationDuration = 0.3
    public var hideAnimationDuration = 0.3
    public var hideOnTap = true

    public var textAlignment: TextAlignment = .center {
        didSet {
            vStack.alignment = vStackAlignment
        }
    }

    public var titleTextColor: UIColor = .black {
        didSet {
            titleLabel.textColor = titleTextColor
        }
    }

    public var darkBackgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00) {
        didSet {
            backgroundColor = viewBackgroundColor
        }
    }

    public var lightBackgroundColor = UIColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1.00) {
        didSet {
            backgroundColor = viewBackgroundColor
        }
    }

    private var overlayWindow: SdkInfoViewWindow?

    public init(title: String, titleFont: UIFont = .systemFont(ofSize: 13, weight: .regular),
                subtitle: String? = nil, subtitleFont: UIFont = .systemFont(ofSize: 11, weight: .regular),
                icon: UIImage? = nil, iconSpacing: CGFloat = 16, position: Position = .top, onTap: (() -> ())? = nil) {
        self.position = position

        super.init(frame: .zero)

        backgroundColor = viewBackgroundColor

        hStack.spacing = iconSpacing

        titleLabel.font = titleFont
        titleLabel.text = title
        vStack.addArrangedSubview(titleLabel)

        if let icon = icon {
            let iconImageView = UIImageView()
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconImageView.widthAnchor.constraint(equalToConstant: 28),
                iconImageView.heightAnchor.constraint(equalToConstant: 28)
            ])
            if #available(iOS 13.0, *) {
                iconImageView.tintColor = .label
            } else {
                iconImageView.tintColor = .black
            }
            iconImageView.image = icon
            hStack.addArrangedSubview(iconImageView)
        }

        if let subtitle = subtitle {
            let subtitleLabel = UILabel()
            if #available(iOS 13.0, *) {
                subtitleLabel.textColor = .secondaryLabel
            } else {
                subtitleLabel.textColor = .lightGray
            }
            subtitleLabel.numberOfLines = 0
            subtitleLabel.font = subtitleFont
            subtitleLabel.text = subtitle
            vStack.addArrangedSubview(subtitleLabel)
        }

        self.onTap = onTap
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tapGestureRecognizer)

        hStack.addArrangedSubview(vStack)
        addSubview(hStack)

        transform = initialTransform
        clipsToBounds = true
    }

    func prepareForShowing() {
        overlayWindow = SdkInfoViewWindow(SdkInfoView: self)
        setupConstraints(position: position)
        setupStackViewConstraints()
        overlayWindow?.isHidden = false
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    @available(iOS 10.0, *)
    public func show(haptic: UINotificationFeedbackGenerator.FeedbackType? = nil) {
        if let hapticType = haptic {
            UINotificationFeedbackGenerator().notificationOccurred(hapticType)
        }
        show()
    }

    public func show() {
        if overlayWindow == nil {
            prepareForShowing()
        } else {
            return
        }
        UIView.animate(withDuration: showAnimationDuration, delay: 0.0, options: .curveEaseOut, animations: {
            self.transform = .identity
        }) { [self] _ in
            if autoHide {
                hide(after: displayTime)
            }
        }
    }

    public func hide(after time: TimeInterval = 0.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + time) {
            UIView.animate(withDuration: self.hideAnimationDuration, delay: 0, options: .curveEaseIn, animations: { [self] in
                transform = initialTransform
            }) { [self] _ in
                removeFromSuperview()
                overlayWindow = nil
            }
        }
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        backgroundColor = viewBackgroundColor
    }

    private func setupConstraints(position: Position) {
        guard let superview = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            centerXAnchor.constraint(equalTo: superview.centerXAnchor),
            leadingAnchor.constraint(greaterThanOrEqualTo: superview.leadingAnchor, constant: 8),
            trailingAnchor.constraint(lessThanOrEqualTo: superview.trailingAnchor, constant: -8),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ]

        switch position {
        case .top:
            if SdkGlobalHelper.DeviceType.IS_IPHONE_14 || SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS || SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX || SdkGlobalHelper.DeviceType.IS_IPHONE_XS || SdkGlobalHelper.DeviceType.IS_IPHONE_8 || SdkGlobalHelper.DeviceType.IS_IPHONE_8P || SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
                constraints += [
                    topAnchor.constraint(equalTo: superview.layoutMarginsGuide.topAnchor, constant: 68),
                    bottomAnchor.constraint(lessThanOrEqualTo: superview.layoutMarginsGuide.bottomAnchor, constant: -8)
                ]
            } else {
                constraints += [
                    topAnchor.constraint(equalTo: superview.layoutMarginsGuide.topAnchor, constant: 90),
                    bottomAnchor.constraint(lessThanOrEqualTo: superview.layoutMarginsGuide.bottomAnchor, constant: -8)
                ]
            }
            
//            constraints += [
//                topAnchor.constraint(equalTo: superview.layoutMarginsGuide.topAnchor, constant: 68),
//                bottomAnchor.constraint(lessThanOrEqualTo: superview.layoutMarginsGuide.bottomAnchor, constant: -8)
//            ]
        case .bottom:
            constraints += [
                bottomAnchor.constraint(equalTo: superview.layoutMarginsGuide.bottomAnchor, constant: -8),
                topAnchor.constraint(greaterThanOrEqualTo: superview.layoutMarginsGuide.topAnchor, constant: 8)
            ]
        }

        NSLayoutConstraint.activate(constraints)
    }

    private func setupStackViewConstraints() {
        hStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            hStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    private func setupShadow() {
        layer.masksToBounds = false
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        layer.shadowRadius = 8
        layer.shadowOpacity = 1
    }

    @objc private func didTap() {
        if hideOnTap {
            hide()
        }
        onTap?()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOSApplicationExtension, unavailable)
class SdkInfoViewWindow: UIWindow {
    init(SdkInfoView: SdkInfoView) {
        if #available(iOS 13.0, *) {
            if let activeForegroundScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                super.init(windowScene: activeForegroundScene)
            } else if let inactiveForegroundScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundInactive }) as? UIWindowScene {
                super.init(windowScene: inactiveForegroundScene)
            } else {
                super.init(frame: UIScreen.main.bounds)
            }
        } else {
            super.init(frame: UIScreen.main.bounds)
        }
        rootViewController = UIViewController()
        windowLevel = .alert
        rootViewController?.view.addSubview(SdkInfoView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let rootViewController = self.rootViewController,
           let SdkInfoView = rootViewController.view.subviews.first as? SdkInfoView {
            return SdkInfoView.frame.contains(point)
        }
        return false
    }
}
