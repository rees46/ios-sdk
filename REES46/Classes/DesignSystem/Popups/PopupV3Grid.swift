import UIKit

// Сетка попапа v3: строки столбиком с промежутком 8; строка — колонки по долям с промежутком
// `gap`, высота не меньше `minHeight`, содержимое обрезается, фон цветом или картинкой; ячейка —
// столбик элементов с тем же `gap`, по вертикали — сверху, по центру или снизу.
//
// Элементы на всю ширину ячейки (картинка, формы, промокод, опрос, рекомендации) тянутся,
// остальные — по содержимому, не шире ячейки, и встают по `cellAlign` или выравниванию ячейки
// (у кнопок и крестика — по `buttonAlign`).

final class PopupV3GridView: UIView {

    private(set) var rowViews: [PopupV3RowView] = []

    init(design: PopupV3Design, context: PopupV3RenderContext) {
        super.init(frame: .zero)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = PopupV3Design.rowsGap
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        rowViews = design.rows.map { PopupV3RowView(row: $0, context: context) }
        rowViews.forEach(stack.addArrangedSubview)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PopupV3RowView: UIView {

    let row: PopupV3Row
    private(set) var cellViews: [PopupV3CellView] = []
    private let background = UIImageView()

    init(row: PopupV3Row, context: PopupV3RenderContext) {
        self.row = row
        super.init(frame: .zero)
        clipsToBounds = true
        backgroundColor = row.backgroundColor?.uiColor
        if let image = row.backgroundImage {
            setUpBackground(image)
        }
        let count = row.fractions.count
        let gaps = CGFloat(max(0, count - 1)) * row.gap
        var previous: UIView?
        var constraints: [NSLayoutConstraint] = [
            heightAnchor.constraint(greaterThanOrEqualToConstant: row.minHeight),
            // Строка по высоте — по самой высокой ячейке, не выше.
            heightAnchor.constraint(equalToConstant: 0).withPriority(UILayoutPriority(50))
        ]
        for (index, cell) in row.cells.enumerated() {
            let view = PopupV3CellView(cell: cell, gap: row.gap, context: context)
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            cellViews.append(view)
            let fraction = row.fractions[index]
            constraints += [
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
                view.widthAnchor.constraint(equalTo: widthAnchor, multiplier: fraction, constant: -gaps * fraction),
                previous.map { view.leadingAnchor.constraint(equalTo: $0.trailingAnchor, constant: row.gap) }
                    ?? view.leadingAnchor.constraint(equalTo: leadingAnchor)
            ]
            previous = view
        }
        NSLayoutConstraint.activate(constraints)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Фон картинкой: `cover`, `contain` или как есть, прижатый по `bgPosition`; плитка — узором.
    private func setUpBackground(_ url: String) {
        background.translatesAutoresizingMaskIntoConstraints = false
        background.clipsToBounds = true
        insertSubview(background, at: 0)
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        switch (row.backgroundSize, row.backgroundPosition) {
        case (.cover, _): background.contentMode = .scaleAspectFill
        case (.contain, _): background.contentMode = .scaleAspectFit
        case (.auto, .top): background.contentMode = .top
        case (.auto, .bottom): background.contentMode = .bottom
        case (.auto, .left): background.contentMode = .left
        case (.auto, .right): background.contentMode = .right
        case (.auto, .center): background.contentMode = .center
        }
        let tiled = row.backgroundRepeat != .noRepeat
        PersonalizationStoryImages.shared.load(url) { [weak self] picture in
            guard let self else { return }
            let image: UIImage?
            switch picture {
            case .image(let value)?: image = value
            case .gif(let gif)?: image = UIImage(data: gif.data)
            case nil: image = nil
            }
            guard let image else { return }
            if tiled {
                self.background.backgroundColor = UIColor(patternImage: image)
            } else {
                self.background.image = image
            }
        }
    }
}

final class PopupV3CellView: UIView {

    let cell: PopupV3Cell
    private(set) var elementViews: [UIView] = []
    private let column = UIView()

    init(cell: PopupV3Cell, gap: CGFloat, context: PopupV3RenderContext) {
        self.cell = cell
        super.init(frame: .zero)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        var constraints: [NSLayoutConstraint] = [
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            column.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ]
        switch Self.justify(cell) {
        case .top: constraints.append(column.topAnchor.constraint(equalTo: topAnchor))
        case .center: constraints.append(column.centerYAnchor.constraint(equalTo: centerYAnchor))
        case .bottom: constraints.append(column.bottomAnchor.constraint(equalTo: bottomAnchor))
        }
        var previous: UIView?
        for element in cell.elements {
            guard let view = PopupV3Elements.make(element, context: context) else { continue }
            view.translatesAutoresizingMaskIntoConstraints = false
            column.addSubview(view)
            elementViews.append(view)
            constraints.append(previous.map { view.topAnchor.constraint(equalTo: $0.bottomAnchor, constant: gap) }
                ?? view.topAnchor.constraint(equalTo: column.topAnchor))
            constraints += Self.horizontal(view, in: column, align: Self.align(element, cell: cell), stretches: element.stretches)
            previous = view
        }
        if let previous {
            constraints.append(previous.bottomAnchor.constraint(equalTo: column.bottomAnchor))
        } else {
            constraints.append(column.heightAnchor.constraint(equalToConstant: 0))
        }
        NSLayoutConstraint.activate(constraints)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Куда прижат столбик в ячейке: один элемент со своим `cellVerticalAlign` встаёт сам, а
    /// если таких несколько — ячейка сверху, как у компилятора.
    static func justify(_ cell: PopupV3Cell) -> PopupV3VAlign {
        let own = cell.elements.compactMap(\.cellVerticalAlign)
        if cell.elements.count == 1, let align = own.first { return align }
        return cell.justify
    }

    /// По горизонтали: `cellAlign` элемента, у кнопок — `buttonAlign`, иначе ячейка.
    static func align(_ element: PopupV3Element, cell: PopupV3Cell) -> PopupV3HAlign {
        if let own = element.cellAlign { return own }
        if element.type == "button" || element.type == "close", let align = PopupV3HAlign(element.value("buttonAlign")) { return align }
        return cell.align
    }

    static func horizontal(_ view: UIView, in column: UIView, align: PopupV3HAlign, stretches: Bool) -> [NSLayoutConstraint] {
        if stretches {
            return [
                view.leadingAnchor.constraint(equalTo: column.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: column.trailingAnchor)
            ]
        }
        // По содержимому, но не шире ячейки: обжатие по ширине слабее рамок ячейки.
        var constraints = [
            view.leadingAnchor.constraint(greaterThanOrEqualTo: column.leadingAnchor),
            view.trailingAnchor.constraint(lessThanOrEqualTo: column.trailingAnchor),
            view.widthAnchor.constraint(equalToConstant: 0).withPriority(UILayoutPriority(60))
        ]
        switch align {
        case .left: constraints.append(view.leadingAnchor.constraint(equalTo: column.leadingAnchor))
        case .center: constraints.append(view.centerXAnchor.constraint(equalTo: column.centerXAnchor))
        case .right: constraints.append(view.trailingAnchor.constraint(equalTo: column.trailingAnchor))
        }
        return constraints
    }
}
