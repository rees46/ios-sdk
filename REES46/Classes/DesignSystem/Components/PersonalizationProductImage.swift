import UIKit

/// Изображение товара с фиксированной пропорцией.
///
/// Источник: Figma Mobile SDK UI Kit, секция Image (88:93), фрейм Product (88:94):
/// три пропорции — 1:1, 4:3, 3:4. Ширину задаёт разметка, высота считается сама.
///
/// Картинку компонент не грузит: сеть — не его дело. Наружу отдан `imageView`,
/// в который хост кладёт изображение своим загрузчиком. До загрузки виден
/// плейсхолдер цвета Background/Card — в макете заливка плейсхолдера
/// к переменной не привязана, взят ближайший токен.
@_spi(PersonalizationUI) public final class PersonalizationProductImage: UIView {

    public enum Aspect {
        case square, landscape, portrait

        var ratio: CGFloat {
            switch self {
            case .square: return 1
            case .landscape: return 4.0 / 3.0
            case .portrait: return 3.0 / 4.0
            }
        }
    }

    /// Сюда хост загружает изображение.
    public let imageView = UIImageView()

    public var aspect: Aspect = .square {
        didSet { applyAspect() }
    }

    private var aspectConstraint: NSLayoutConstraint?

    public init(aspect: Aspect = .square) {
        super.init(frame: .zero)
        self.aspect = aspect
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        backgroundColor = PersonalizationColor.backgroundCard
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        applyAspect()
    }

    private func applyAspect() {
        aspectConstraint?.isActive = false
        let constraint = heightAnchor.constraint(equalTo: widthAnchor, multiplier: 1 / aspect.ratio)
        constraint.isActive = true
        aspectConstraint = constraint
    }
}
