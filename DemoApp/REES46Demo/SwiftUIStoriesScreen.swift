import SwiftUI
import Combine
import REES46

/// "UI Kit" tab — the SDK's UI built the modern way, through the SwiftUI wrappers.
///
/// The counterpart of `LegacyStoriesViewController`, which shows the same stories block through
/// the UIKit `StoriesView`.
struct SwiftUIStoriesScreen: View {

    @State private var sdk: PersonalizationSDK?
    @State private var loadState: LoadState = .waitingForSdk
    @State private var events: [String] = []
    @State private var routeOwnScheme = false

    private enum LoadState {
        case waitingForSdk
        case loading
        case loaded
        case failed

        var title: String {
            switch self {
            case .waitingForSdk: return "Waiting for the SDK to initialise…"
            case .loading: return "Loading stories…"
            case .loaded: return "Stories loaded"
            case .failed: return "Stories failed to load"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("StoriesWidget") {
                    if let sdk = sdk {
                        storiesWidget(sdk: sdk)
                    } else {
                        placeholder
                    }
                    Text(loadState.title)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                section("Link routing") {
                    Toggle("Route demo:// links in the app", isOn: $routeOwnScheme)
                    Text(routeOwnScheme
                         ? "demo:// links are handled here, everything else is opened by the SDK"
                         : "Every link is opened by the SDK")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                section("Events") {
                    if events.isEmpty {
                        Text("Tap a story to see callbacks here")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(events.indices, id: \.self) { index in
                            Text(events[index])
                                .font(.system(.footnote, design: .monospaced))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear { attachSdk() }
        .onReceive(NotificationCenter.default.publisher(for: globalSDKNotificationNameMainInit).receive(on: DispatchQueue.main)) { _ in
            attachSdk()
        }
    }

    // MARK: - Pieces

    private func storiesWidget(sdk: PersonalizationSDK) -> some View {
        StoriesWidget(sdk: sdk, code: AppEnvironments.storiesCode)
            .onStoriesLoad { isLoaded in
                loadState = isLoaded ? .loaded : .failed
            }
            .onCollapse { _ in
                log("onCollapse: nothing to show, row collapsed")
            }
            .onSelectProduct { element in
                log("onSelectProduct: \(element.deeplinkIos ?? element.link ?? "no link")")
            }
            .onSelectCarouselProduct { product in
                log("onSelectCarouselProduct: \(product.deeplinkIos)")
            }
            .onSelectPromocode { promocode in
                log("onSelectPromocode (StoriesPromoCodeElement exposes no public fields)")
            }
            .onReceiveLink { url in
                log("onReceiveLink: \(url)")
            }
            .openLinkBySdk { url in
                guard routeOwnScheme, url.hasPrefix("demo://") else { return true }
                log("routed by the app, SDK skipped: \(url)")
                return false
            }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.15))
            .frame(height: StoriesWidget.defaultHeight)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    // MARK: - State

    private func attachSdk() {
        guard sdk == nil, let globalSDK = globalSDK else { return }
        sdk = globalSDK
        loadState = .loading
    }

    private func log(_ message: String) {
        events.insert(message, at: 0)
        if events.count > 20 {
            events.removeLast()
        }
    }
}
