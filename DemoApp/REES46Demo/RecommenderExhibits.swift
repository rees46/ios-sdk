import SwiftUI
import UIKit
import REES46

/// The data-bound recommender block in the "Blocks" segment: the demo shop's block as a carousel,
/// the same block as a grid, and the SwiftUI wrapper. Under each block — what `onLoaded` or
/// `onError` reported. There is no skeleton: while the block loads it takes no space at all.
/// Taps only show a toast — navigation is the host's.
enum RecommenderExhibits {

    /// A recommender block of the demo shop (c1140c…, api.rees46.ru).
    static let code = "e6249bb15043644bf25b135006149962"

    static func all() -> [ShowcaseViewController.Exhibit] {
        [
            ("Recommender Block — live, carousel (block \(code))", { LiveRecommenderExhibit(layout: .carousel) }),
            ("Recommender Block — live, the same block as a grid of 4", { LiveRecommenderExhibit(layout: .grid) }),
            ("Recommender Block — SwiftUI, a list of 3 with its own title", { SwiftUIRecommenderExhibit() })
        ]
    }

    static func describe(_ product: PersonalizationProduct) -> String {
        "\(product.name)\n\(product.deeplink ?? product.url ?? "no link")"
    }
}

/// The block as a UIKit host drops it in: the code, the shop, a card button and the callbacks.
private final class LiveRecommenderExhibit: UIStackView {

    private let block: PersonalizationRecommenderBlock
    private let status = UILabel()

    init(layout: PersonalizationProductsList.Layout) {
        block = PersonalizationRecommenderBlock(code: RecommenderExhibits.code, shopId: AppEnvironments.shopId, layout: layout)
        super.init(frame: .zero)
        axis = .vertical
        spacing = 8

        block.actionText = "Add to cart"
        if layout == .carousel {
            block.showAllText = "Show all"
            block.onShowAll = { PersonalizationToast.show("Show all") }
        } else {
            block.limit = 4
        }
        block.onProductTap = { PersonalizationToast.show("Open: " + RecommenderExhibits.describe($0)) }
        block.onProductAction = { PersonalizationToast.show("Add to cart: \($0.name)") }
        block.onLoaded = { [weak self] count in
            self?.status.text = count > 0 ? "onLoaded: \(count) products" : "onLoaded: 0 — the block is hidden"
        }
        block.onError = { [weak self] error in self?.status.text = "onError: \(error) — the block is hidden" }

        status.text = "Loading…"
        status.font = .preferredFont(forTextStyle: .caption1)
        status.textColor = .secondaryLabel
        status.numberOfLines = 0

        let reload = PersonalizationButton(text: "Reload past the cache", size: .sm, view: .secondary)
        reload.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        let row = UIStackView(arrangedSubviews: [reload, UIView()])

        addArrangedSubview(block)
        addArrangedSubview(status)
        addArrangedSubview(row)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func reloadTapped() {
        status.text = "Reloading…"
        block.reload()
    }
}

// MARK: - SwiftUI

/// The SwiftUI wrapper in a hosting controller, the way a SwiftUI screen embeds it.
private final class SwiftUIRecommenderExhibit: UIView {

    private let hosting = UIHostingController(rootView: SwiftUIRecommender())

    init() {
        super.init(frame: .zero)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        if #available(iOS 16.0, *) {
            hosting.sizingOptions = .intrinsicContentSize
        } else {
            hosting.view.heightAnchor.constraint(equalToConstant: 600).isActive = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, hosting.parent == nil else { return }
        var responder: UIResponder? = self
        while let current = responder, !(current is UIViewController) { responder = current.next }
        guard let parent = responder as? UIViewController else { return }
        parent.addChild(hosting)
        hosting.didMove(toParent: parent)
    }
}

private struct SwiftUIRecommender: View {
    @State private var controller = PersonalizationRecommenderBlockController()
    @State private var status = "Loading…"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PersonalizationRecommenderBlockWidget(
                code: RecommenderExhibits.code,
                shopId: AppEnvironments.shopId,
                layout: .list,
                title: "You may also like",
                limit: 3,
                actionText: "Add to cart",
                controller: controller,
                onProductTap: { PersonalizationToast.show("Open: " + RecommenderExhibits.describe($0)) },
                onProductAction: { PersonalizationToast.show("Add to cart: \($0.name)") },
                onLoaded: { status = "onLoaded: \($0)" },
                onError: { status = "onError: \($0)" }
            )
            Button("Reload past the cache") {
                status = "Reloading…"
                controller.reload()
            }
            .font(.footnote)
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
