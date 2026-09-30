import UIKit

/// Ряд с переносом: дети идут слева направо и переходят на новую строку,
/// когда не влезают. Нужен тегам подсказок поиска — в макете они лежат
/// во flex-wrap с шагом 8 по обеим осям, а не в горизонтальном скролле.
///
/// Высота зависит от ширины, поэтому после каждой раскладки вью пересчитывает
/// свой intrinsicContentSize: стек, в котором она лежит, подхватывает новую высоту
/// следующим проходом.
final class PersonalizationFlowView: UIView {

    private let horizontalGap: CGFloat
    private let verticalGap: CGFloat
    private var measuredWidth: CGFloat = 0
    private var measuredHeight: CGFloat = 0

    init(horizontalGap: CGFloat, verticalGap: CGFloat) {
        self.horizontalGap = horizontalGap
        self.verticalGap = verticalGap
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setItems(_ views: [UIView]) {
        subviews.forEach { $0.removeFromSuperview() }
        views.forEach(addSubview)
        measuredWidth = 0
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : Self.fallbackWidth
        return CGSize(width: UIView.noIntrinsicMetric, height: height(for: width))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for view in subviews where !view.isHidden {
            let size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x > 0 && x + horizontalGap + size.width > width {
                x = 0
                y += lineHeight + verticalGap
                lineHeight = 0
            } else if x > 0 {
                x += horizontalGap
            }
            view.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            x += size.width
            lineHeight = max(lineHeight, size.height)
        }
        let height = subviews.contains { !$0.isHidden } ? y + lineHeight : 0
        if width != measuredWidth || height != measuredHeight {
            measuredWidth = width
            measuredHeight = height
            invalidateIntrinsicContentSize()
        }
    }

    private func height(for width: CGFloat) -> CGFloat {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var any = false
        for view in subviews where !view.isHidden {
            any = true
            let size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x > 0 && x + horizontalGap + size.width > width {
                x = 0
                y += lineHeight + verticalGap
                lineHeight = 0
            } else if x > 0 {
                x += horizontalGap
            }
            x += size.width
            lineHeight = max(lineHeight, size.height)
        }
        return any ? y + lineHeight : 0
    }

    private static let fallbackWidth: CGFloat = 320
}
