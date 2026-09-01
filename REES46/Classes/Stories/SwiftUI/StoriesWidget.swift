#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// SwiftUI wrapper around the UIKit `StoriesView`.
///
/// `StoriesView` needs a view controller to present the full screen story viewer from, and it
/// reports taps through `StoriesCommunicationProtocol`. Neither fits SwiftUI, so the wrapper
/// resolves the presenting controller from the view hierarchy and turns the delegate into
/// closures:
///
/// ```swift
/// StoriesWidget(sdk: sdk, code: "stories_code")
///     .onSelectProduct { element in router.open(element) }
///     .openLinkBySdk { !$0.hasPrefix("myshop://") }
/// ```
///
/// The widget is a fixed height row — pass `height` to override the default. Every closure is
/// optional: with none of them set the SDK opens tapped links itself, which is the same
/// behaviour a UIKit host gets without a `communicationDelegate`.
/// SwiftUI needs iOS 13; the rest of the SDK still supports 12, so the wrapper is gated rather than
/// the whole pod. Nested `Container` and `Coordinator` inherit this availability.
@available(iOS 13.0, *)
public struct StoriesWidget: View {

    /// Height of the stories row in the UIKit collection layout.
    public static let defaultHeight: CGFloat = 135

    private let sdk: PersonalizationSDK
    private let code: String
    private let height: CGFloat
    private var callbacks = Callbacks()

    public init(
        sdk: PersonalizationSDK,
        code: String,
        height: CGFloat = StoriesWidget.defaultHeight
    ) {
        self.sdk = sdk
        self.code = code
        self.height = height
    }

    public var body: some View {
        Container(sdk: sdk, code: code, callbacks: callbacks)
            .frame(height: height)
    }

    // MARK: - Callbacks

    /// Called with the result of loading the stories block.
    public func onStoriesLoad(_ handler: @escaping (Bool) -> Void) -> StoriesWidget {
        modifying { $0.onLoad = handler }
    }

    /// Called when a slide button carrying a product is tapped.
    public func onSelectProduct(_ handler: @escaping (StoriesElement) -> Void) -> StoriesWidget {
        modifying { $0.onSelectProduct = handler }
    }

    /// Called when a product inside the slide carousel is tapped.
    public func onSelectCarouselProduct(_ handler: @escaping (StoriesProduct) -> Void) -> StoriesWidget {
        modifying { $0.onSelectCarouselProduct = handler }
    }

    /// Called when a promocode slide is tapped.
    public func onSelectPromocode(_ handler: @escaping (StoriesPromoCodeElement) -> Void) -> StoriesWidget {
        modifying { $0.onSelectPromocode = handler }
    }

    /// Called with the raw `linkIos` of the tapped element.
    public func onReceiveLink(_ handler: @escaping (String) -> Void) -> StoriesWidget {
        modifying { $0.onReceiveLink = handler }
    }

    /// Decides whether the SDK opens a tapped url itself.
    ///
    /// Return `false` for urls the host routes on its own, otherwise the destination is opened
    /// twice. Without this modifier the SDK opens every url, matching the default of
    /// `StoriesCommunicationProtocol.shouldOpenLinkBySdk(url:)`.
    public func openLinkBySdk(_ decide: @escaping (String) -> Bool) -> StoriesWidget {
        modifying { $0.shouldOpenLinkBySdk = decide }
    }

    private func modifying(_ change: (inout Callbacks) -> Void) -> StoriesWidget {
        var copy = self
        change(&copy.callbacks)
        return copy
    }

    // MARK: - Plumbing

    fileprivate struct Callbacks {
        var onLoad: ((Bool) -> Void)?
        var onSelectProduct: ((StoriesElement) -> Void)?
        var onSelectCarouselProduct: ((StoriesProduct) -> Void)?
        var onSelectPromocode: ((StoriesPromoCodeElement) -> Void)?
        var onReceiveLink: ((String) -> Void)?
        var shouldOpenLinkBySdk: ((String) -> Bool)?
    }

    private struct Container: UIViewRepresentable {
        let sdk: PersonalizationSDK
        let code: String
        let callbacks: Callbacks

        func makeCoordinator() -> Coordinator {
            Coordinator(sdk: sdk, code: code, callbacks: callbacks)
        }

        func makeUIView(context: Context) -> StoriesView {
            let view = StoriesView(frame: .zero)
            view.communicationDelegate = context.coordinator
            return view
        }

        func updateUIView(_ uiView: StoriesView, context: Context) {
            context.coordinator.callbacks = callbacks
            context.coordinator.configureIfNeeded(uiView)
        }
    }

    fileprivate final class Coordinator: StoriesCommunicationProtocol {
        var callbacks: Callbacks

        private let sdk: PersonalizationSDK
        private let code: String
        private var isConfigured = false
        /// `configure` loads the block, so it has to run exactly once — and only once a
        /// presenting controller exists. SwiftUI can call `updateUIView` before the view is in
        /// the hierarchy, hence the bounded retry instead of a single attempt.
        private var remainingAttempts = 10

        init(sdk: PersonalizationSDK, code: String, callbacks: Callbacks) {
            self.sdk = sdk
            self.code = code
            self.callbacks = callbacks
        }

        func configureIfNeeded(_ view: StoriesView) {
            guard !isConfigured else { return }

            guard let presenter = view.presentingParentViewController else {
                guard remainingAttempts > 0 else { return }
                remainingAttempts -= 1
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self = self, let view = view else { return }
                    self.configureIfNeeded(view)
                }
                return
            }

            isConfigured = true
            view.onStoriesLoadComplete = { [weak self] isLoaded in
                self?.callbacks.onLoad?(isLoaded)
            }
            view.configure(sdk: sdk, mainVC: presenter, code: code)
        }

        func receiveIosLink(text: String) {
            callbacks.onReceiveLink?(text)
        }

        func receiveSelectedProductData(products: StoriesElement) {
            callbacks.onSelectProduct?(products)
        }

        func receiveSelectedCarouselProductData(products: StoriesProduct) {
            callbacks.onSelectCarouselProduct?(products)
        }

        func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {
            callbacks.onSelectPromocode?(promoCodeSlide)
        }

        func shouldOpenLinkBySdk(url: String) -> Bool {
            callbacks.shouldOpenLinkBySdk?(url) ?? true
        }
    }
}

private extension UIView {
    /// Nearest controller up the responder chain — the hosting controller when the view is
    /// rendered by SwiftUI. `StoriesView` presents the story viewer from it.
    var presentingParentViewController: UIViewController? {
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller
            }
            responder = current.next
        }
        return nil
    }
}
#endif
