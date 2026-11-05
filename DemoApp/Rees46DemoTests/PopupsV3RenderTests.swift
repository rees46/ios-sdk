import XCTest
import UIKit
@_spi(PersonalizationUI) @testable import REES46

/// Popups v3, the native render: the grid laid out at a fixed width, the element registry (unknown
/// and hidden elements are skipped), the frame that scrolls, the window rules of the layouts, the
/// slot shared with legacy popups, and what each interactive element sends.
final class PopupsV3RenderTests: XCTestCase {

    final class Actions: PopupV3Actions {
        var sdk: PersonalizationSDK?
        var succeeds = true
        private(set) var opened: [String] = []
        private(set) var products: [String] = []
        private(set) var copied: [String] = []
        private(set) var events: [String] = []
        private(set) var closed = 0
        private(set) var subscriptions: [(email: String, consents: [String])] = []
        private(set) var profiles: [PopupV3Profile] = []
        private(set) var segments: [String] = []
        private(set) var reviews: [(kind: PersonalizationStoryPoll.Scale, body: [String: Any])] = []

        func open(_ link: String) { opened.append(link) }
        func product(_ product: PersonalizationProduct) { products.append(product.id) }
        func copy(_ text: String, toast: String?) { copied.append(text) }
        func event(_ name: String, channel: String?) { events.append(channel.map { "\(name):\($0)" } ?? name) }
        func close() { closed += 1 }
        func relayout() {}

        func subscribe(email: String, consents: [String], completion: @escaping (Bool) -> Void) {
            subscriptions.append((email, consents))
            completion(succeeds)
        }

        func saveProfile(_ profile: PopupV3Profile, completion: @escaping (Bool) -> Void) {
            profiles.append(profile)
            completion(succeeds)
        }

        func addToSegment(_ id: String, completion: @escaping (Bool) -> Void) {
            segments.append(id)
            completion(succeeds)
        }

        func review(kind: PersonalizationStoryPoll.Scale, body: [String: Any], completion: @escaping (Bool) -> Void) {
            reviews.append((kind, body))
            completion(succeeds)
        }
    }

    private var actions: Actions!
    private var context: PopupV3RenderContext!

    override func setUp() {
        super.setUp()
        actions = Actions()
        context = PopupV3RenderContext(runtime: [:], texts: .ru, screenSize: CGSize(width: 390, height: 844), actions: actions)
    }

    private func make(_ name: String, _ id: String, runtime: [String: String] = [:]) -> UIView? {
        let context = runtime.isEmpty ? self.context! : PopupV3RenderContext(runtime: runtime, texts: .ru, screenSize: CGSize(width: 390, height: 844), actions: actions)
        return PopupV3Elements.make(PopupsV3Fixtures.element(name, id), context: context)
    }

    /// The grid in a container `width` wide, laid out.
    private func layOut(_ design: PopupV3Design, width: CGFloat) -> PopupV3GridView {
        let grid = PopupV3GridView(design: design, context: context)
        grid.translatesAutoresizingMaskIntoConstraints = false
        let host = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 2000))
        host.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: host.topAnchor),
            grid.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            grid.widthAnchor.constraint(equalToConstant: width)
        ])
        host.layoutIfNeeded()
        host.layoutIfNeeded()
        return grid
    }

    private func descendant<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match = descendant(type, in: subview) { return match }
        }
        return nil
    }

    private func assertWidths(_ views: [UIView], _ widths: [CGFloat], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(views.count, widths.count, file: file, line: line)
        for (view, width) in zip(views, widths) {
            XCTAssertEqual(view.frame.width, width, accuracy: 0.5, file: file, line: line)
        }
    }

    // MARK: - Grid

    func testGridColumnsGapsHeightsAndAlignment() {
        let grid = layOut(PopupsV3Fixtures.design("grid"), width: 300)
        XCTAssertEqual(grid.rowViews.count, 4)

        let a = grid.rowViews[0]
        assertWidths(a.cellViews, [144, 144])
        XCTAssertEqual(a.cellViews[1].frame.minX, 156, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(a.frame.height, 80)
        XCTAssertEqual(a.cellViews[0].elementViews.map(\.accessibilityIdentifier), ["popupV3.a0-1", "popupV3.a0-2", "popupV3.a0-3"])
        let button = a.cellViews[1].elementViews[0]
        XCTAssertEqual(button.frame.midX, a.cellViews[1].bounds.midX, accuracy: 0.5, "a button stands by buttonAlign (center)")
        XCTAssertGreaterThan(a.cellViews[0].elementViews[1].frame.minY, a.cellViews[0].elementViews[0].frame.maxY + 11, "gap 12")

        let b = grid.rowViews[1]
        XCTAssertEqual(b.frame.minY, a.frame.maxY + 8, accuracy: 0.5, "rows go 8 apart")
        XCTAssertEqual(b.frame.height, 60, accuracy: 0.5)
        let b0 = b.cellViews[0].elementViews[0]
        XCTAssertEqual(b0.convert(b0.bounds, to: b.cellViews[0]).maxY, 60, accuracy: 0.5, "bottom-justified cell")
        XCTAssertEqual(b0.convert(b0.bounds, to: b.cellViews[0]).maxX, b.cellViews[0].bounds.width, accuracy: 0.5, "right-aligned row")

        let c = grid.rowViews[2]
        XCTAssertEqual(c.frame.height, 110, accuracy: 0.5, "minHeight null — 110")
        assertWidths(c.cellViews, [73, 219])
        let c1 = c.cellViews[1].elementViews[0]
        XCTAssertEqual(c1.convert(c1.bounds, to: c.cellViews[1]).maxX, c.cellViews[1].bounds.width, accuracy: 0.5, "cellAlign right")
        XCTAssertEqual(c.backgroundColor, CSSColor.parse("#fef3c7")?.uiColor)

        let d = grid.rowViews[3]
        assertWidths(d.cellViews, [28, 28, 56, 56, 56, 56])
        XCTAssertEqual(d.cellViews[5].elementViews.count, 1)
    }

    func testUnknownHiddenAndEmptyElementsAreNotRendered() {
        let grid = layOut(PopupsV3Fixtures.design("unknown-element"), width: 300)
        XCTAssertEqual(grid.rowViews[0].cellViews[0].elementViews.map(\.accessibilityIdentifier), ["popupV3.ok", "popupV3.bad-style"])
        XCTAssertNil(make("element-image", "el-img-hidden"))
        XCTAssertNotNil(make("element-image", "el-img-auto"))
        XCTAssertNil(make("element-recommendation", "el-rec-empty"))
        XCTAssertNil(PopupV3Elements.make(PopupV3Element(id: "w", type: "wheel", style: [:]), context: context))
    }

    func testAnImageWithARatioIsAsTallAsItsWidthAllows() {
        let design = PopupV3Design(json: [
            "rows": [["id": "r", "columns": [100], "minHeight": 0]],
            "elements": [["id": "i", "type": "image", "rowId": "r", "partIndex": 0, "style": ["imageUrl": "https://example.com/a.png", "imageAspectRatio": "2 / 1", "imageRadius": 0]]]
        ])
        let grid = layOut(design, width: 300)
        XCTAssertEqual(grid.rowViews[0].frame.height, 150, accuracy: 0.5)
    }

    // MARK: - Frame

    func testTheFrameScrollsWhenTheContentIsTaller() {
        let list = PopupsV3List(payload: PopupsV3Fixtures.json("live-list-181-182")["payload"] as? [String: Any] ?? [:])
        let banner = list.popups[0]
        let design = PopupV3Design(json: banner.design)
        let frame = PopupV3FrameView(design: design, context: context)
        frame.translatesAutoresizingMaskIntoConstraints = false
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        host.addSubview(frame)
        NSLayoutConstraint.activate([frame.topAnchor.constraint(equalTo: host.topAnchor), frame.leadingAnchor.constraint(equalTo: host.leadingAnchor)])
        let geometry = PopupV3Geometry(layout: .banner, placement: .top, style: design.frame, bounds: host.bounds.size, safe: UIEdgeInsets(top: 300, left: 0, bottom: 300, right: 0))
        frame.apply(geometry)
        host.layoutIfNeeded()
        host.layoutIfNeeded()
        XCTAssertEqual(geometry.maxHeight, 844 - 600 - 16)
        XCTAssertEqual(frame.frame.height, geometry.maxHeight, accuracy: 0.5, "the frame stops at the available height")
        XCTAssertEqual(frame.frame.width, 390 * 0.92, accuracy: 0.5)
        XCTAssertTrue(frame.isScrollable, "the rest scrolls inside the frame")
        XCTAssertEqual(frame.scrollView.frame.minY, 21, accuracy: 0.5, "padding 20 + border 1 stay in place")
    }

    func testAShortPopupHugsItsContentAndKeepsMinHeight() {
        let popups = PopupsV3Fixtures.json("layouts")["popups"] as? [[String: Any]] ?? []
        let modal = PopupV3(json: popups[2])!
        let modalDesign = PopupV3Design(json: modal.design)
        let frame = PopupV3FrameView(design: modalDesign, context: context)
        frame.translatesAutoresizingMaskIntoConstraints = false
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        host.addSubview(frame)
        NSLayoutConstraint.activate([frame.topAnchor.constraint(equalTo: host.topAnchor), frame.leadingAnchor.constraint(equalTo: host.leadingAnchor)])
        frame.apply(PopupV3Geometry(layout: .modal, placement: .center, style: modalDesign.frame, bounds: host.bounds.size, safe: .zero))
        host.layoutIfNeeded()
        XCTAssertEqual(frame.frame.height, 200, accuracy: 0.5, "minHeight 200 over a short content")
        XCTAssertFalse(frame.isScrollable)
    }

    func testLayoutRulesOfTheWindow() {
        let popups = (PopupsV3Fixtures.json("layouts")["popups"] as? [[String: Any]] ?? []).compactMap(PopupV3.init(json:))
        func controller(_ popup: PopupV3) -> PopupV3ViewController {
            let presentation = PopupV3Presentation(popup: popup, design: PopupV3Design(json: popup.design), runtime: [:], onEvent: { _, _ in }, onClose: {})
            return PopupV3ViewController(presentation: presentation, actions: PopupV3SDKActions(sdk: nil, appHost: "app.rees46.ru", linkHandler: nil, onEvent: { _, _ in }), hostStatusBar: nil)
        }
        let top = controller(popups[0])
        XCTAssertFalse(top.hasOverlay)
        XCTAssertFalse(top.blocksOutside, "touches outside the banner reach the app")
        let bottom = controller(popups[1])
        XCTAssertTrue(bottom.hasOverlay)
        XCTAssertTrue(bottom.blocksOutside)
        let modal = controller(popups[2])
        XCTAssertTrue(modal.hasOverlay, "a modal is dimmed by default")
        XCTAssertTrue(modal.blocksOutside)
        let full = controller(popups[3])
        XCTAssertFalse(full.hasOverlay)
        XCTAssertTrue(full.blocksOutside)
    }

    func testThePopupWindowLeavesTheKeyWindowToTheApp() throws {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard let host = windows.first(where: \.isKeyWindow) else { throw XCTSkip("the test host has no key window") }
        let popup = try XCTUnwrap(PopupV3(json: ["id": 77, "layout": "modal", "trigger_type": "manual"]))
        let design = PopupsV3Fixtures.design("element-text")
        var closed = false
        let presentation = PopupV3Presentation(popup: popup, design: design, runtime: [:], onEvent: { _, _ in }, onClose: {})
        let controller = PopupV3ViewController(
            presentation: presentation,
            actions: PopupV3SDKActions(sdk: nil, appHost: "app.rees46.ru", linkHandler: nil, onEvent: { _, _ in }),
            hostStatusBar: nil
        )
        controller.onClosed = { closed = true }
        controller.show(over: host)
        XCTAssertEqual(controller.window?.isHidden, false)
        XCTAssertTrue(host.isKeyWindow, "hosts that present from keyWindow keep working while a popup is open")
        controller.close(sendingEvent: false)
        let deadline = Date().addingTimeInterval(2)
        while !closed, Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        XCTAssertTrue(closed)
        XCTAssertNil(controller.window)
    }

    /// The controller of `popup` with the text fixture's design under `frame`; events go to `events`.
    private func makeController(_ popup: [String: Any], frame: [String: Any] = [:], design name: String = "element-text", events: @escaping (String) -> Void = { _ in }, productHandler: ((PersonalizationProduct) -> Bool)? = nil, linkHandler: ((URL) -> Bool)? = nil) throws -> PopupV3ViewController {
        var json = PopupsV3Fixtures.json(name)["design"] as? [String: Any] ?? [:]
        json["frameStyle"] = (json["frameStyle"] as? [String: Any] ?? [:]).merging(frame) { $1 }
        let presentation = PopupV3Presentation(
            popup: try XCTUnwrap(PopupV3(json: popup)), design: PopupV3Design(json: json), runtime: [:],
            onEvent: { name, _ in events(name) }, onClose: {}
        )
        let actions = PopupV3SDKActions(
            sdk: nil, appHost: "app.rees46.ru", linkHandler: linkHandler, productHandler: productHandler, onEvent: presentation.onEvent
        )
        return PopupV3ViewController(presentation: presentation, actions: actions, hostStatusBar: nil)
    }

    func testATapOutsideClosesOnlyOverTheOverlay() throws {
        let modal: [String: Any] = ["id": 80, "layout": "modal", "trigger_type": "manual"]
        let banner: [String: Any] = ["id": 81, "layout": "banner", "placement": "bottom", "trigger_type": "manual"]
        func tapOutside(_ popup: [String: Any], _ frame: [String: Any]) throws -> [String] {
            var events: [String] = []
            let controller = try makeController(popup, frame: frame, events: { events.append($0) })
            controller.loadViewIfNeeded()
            controller.tappedOutside()
            XCTAssertEqual(controller.isClosing, !events.isEmpty)
            return events
        }
        XCTAssertEqual(try tapOutside(modal, [:]), ["close"], "a dimmed modal closes")
        XCTAssertEqual(try tapOutside(modal, ["overlayEnabled": false]), [], "without the overlay the tap is swallowed")
        XCTAssertEqual(try tapOutside(banner, ["overlayEnabled": true]), ["close"])
        XCTAssertEqual(try tapOutside(banner, ["lockBackgroundScroll": true]), [], "a locked background without the overlay")
    }

    func testTheFirstTapOutsideOnlyHidesTheKeyboard() throws {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard let host = windows.first(where: \.isKeyWindow) else { throw XCTSkip("the test host has no key window") }
        var events: [String] = []
        var closed = false
        let controller = try makeController(
            ["id": 82, "layout": "modal", "trigger_type": "manual"], design: "element-email-collector", events: { events.append($0) }
        )
        controller.onClosed = { closed = true }
        controller.show(over: host)
        defer {
            controller.close(sendingEvent: false)
            let deadline = Date().addingTimeInterval(2)
            while !closed, Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        }
        let field = try XCTUnwrap(descendant(PopupV3EmailView.self, in: controller.frameView)).field
        guard field.becomeFirstResponder() else { throw XCTSkip("the field cannot take the keyboard here") }
        controller.tappedOutside()
        XCTAssertFalse(field.isFirstResponder, "the first tap hides the keyboard")
        XCTAssertEqual(events, [])
        XCTAssertFalse(controller.isClosing)
        controller.tappedOutside()
        XCTAssertEqual(events, ["close"], "the next one closes")
    }

    private func waitUntil(_ done: @autoclosure () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !done(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    }

    func testAFeedProductGoesToTheHostThenToItsLink() throws {
        var events: [String] = []
        var products: [String] = []
        var links: [String] = []
        var system: [String] = []
        var hostOpens = false
        var closed = false
        let controller = try makeController(
            ["id": 83, "layout": "modal", "trigger_type": "manual"], events: { events.append($0) },
            productHandler: { products.append($0.id); return hostOpens },
            linkHandler: { links.append($0.absoluteString); return false }
        )
        controller.onClosed = { closed = true }
        let actions = controller.actions
        actions.openSystem = { system.append($0.absoluteString) }
        actions.product(PersonalizationProduct(id: "1", name: "A", price: "1", url: "https://demo.rees46.ru/p/1", deeplink: "rees46demo://product/1"))
        actions.product(PersonalizationProduct(id: "2", name: "B", price: "1", url: "https://demo.rees46.ru/p/2", deeplink: " "))
        actions.product(PersonalizationProduct(id: "3", name: "C", price: "1"))
        XCTAssertEqual(products, ["1", "2", "3"])
        XCTAssertEqual(links, ["rees46demo://product/1", "https://demo.rees46.ru/p/2"], "deeplink, then url; nothing without both")
        XCTAssertEqual(system, links, "the link hook left them to the system")
        XCTAssertFalse(controller.isClosing, "the popup stays after a link the system opened")

        hostOpens = true
        actions.product(PersonalizationProduct(id: "4", name: "D", price: "1", url: "https://demo.rees46.ru/p/4"))
        XCTAssertEqual(links.count, 2, "the host opened it: no link")
        XCTAssertTrue(controller.isClosing, "the host opened it: the popup goes")
        waitUntil(closed)
        XCTAssertTrue(closed)
        XCTAssertEqual(events, [], "no close after a transition")

        var opened: [String] = []
        let bare = PopupV3SDKActions(sdk: nil, appHost: "app.rees46.ru", linkHandler: { opened.append($0.absoluteString); return true }, onEvent: { _, _ in })
        bare.product(PersonalizationProduct(id: "5", name: "E", price: "1", url: "https://demo.rees46.ru/p/5"))
        XCTAssertEqual(opened, ["https://demo.rees46.ru/p/5"], "without a hook the link opens")
    }

    func testAFeedProductWhoseLinkTheHostOpenedClosesThePopup() throws {
        var events: [String] = []
        var closed = false
        let controller = try makeController(
            ["id": 84, "layout": "modal", "trigger_type": "manual"], events: { events.append($0) },
            productHandler: { _ in false }, linkHandler: { _ in true }
        )
        controller.onClosed = { closed = true }
        controller.actions.openSystem = { XCTFail("the host opened \($0)") }
        controller.actions.product(PersonalizationProduct(id: "1", name: "A", price: "1", url: "https://demo.rees46.ru/p/1"))
        XCTAssertTrue(controller.isClosing, "the product's link goes the way of any link")
        waitUntil(closed)
        XCTAssertEqual(events, [])
    }

    // MARK: - Links the host opens itself

    /// The link button of the button fixture in a controller of its design.
    private func linkButton(in controller: PopupV3ViewController) throws -> PopupV3ButtonControl {
        controller.loadViewIfNeeded()
        let element = try XCTUnwrap(descendant(of: controller.frameView, identifier: "popupV3.el-btn-link"))
        return try XCTUnwrap(descendant(PopupV3ButtonControl.self, in: element))
    }

    private func descendant(of view: UIView, identifier: String) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        return view.subviews.lazy.compactMap { self.descendant(of: $0, identifier: identifier) }.first
    }

    func testALinkTheHostOpenedClosesThePopupWithoutClose() throws {
        var events: [String] = []
        var links: [String] = []
        var closed = false
        let controller = try makeController(
            ["id": 85, "layout": "modal", "trigger_type": "manual"], design: "element-button", events: { events.append($0) },
            linkHandler: { links.append($0.absoluteString); return true }
        )
        controller.onClosed = { closed = true }
        controller.actions.openSystem = { XCTFail("the host opened \($0)") }
        try linkButton(in: controller).sendActions(for: .touchUpInside)
        XCTAssertEqual(links, ["rees46demo://sale?from=ios"])
        XCTAssertTrue(controller.isClosing, "the host opened the link: the popup goes")
        waitUntil(closed)
        XCTAssertTrue(closed)
        XCTAssertEqual(events, ["click"], "click first; no close after a transition")
    }

    func testALinkTheHostLeftGoesToTheSystemAndThePopupStays() throws {
        let hooks: [(name: String, hook: ((URL) -> Bool)?)] = [("no hook", nil), ("a hook that declines", { _ in false })]
        for (name, hook) in hooks {
            var events: [String] = []
            var system: [String] = []
            let controller = try makeController(
                ["id": 86, "layout": "modal", "trigger_type": "manual"], design: "element-button", events: { events.append($0) },
                linkHandler: hook
            )
            controller.actions.openSystem = { system.append($0.absoluteString) }
            try linkButton(in: controller).sendActions(for: .touchUpInside)
            XCTAssertEqual(system, ["rees46demo://sale?from=ios"], name)
            XCTAssertFalse(controller.isClosing, name)
            XCTAssertEqual(events, ["click"], name)
        }
    }

    func testALinkedTextTheHostOpenedClosesThePopupToo() throws {
        var events: [String] = []
        var links: [String] = []
        var closed = false
        let controller = try makeController(
            ["id": 87, "layout": "modal", "trigger_type": "manual"], events: { events.append($0) },
            linkHandler: { links.append($0.absoluteString); return true }
        )
        controller.onClosed = { closed = true }
        controller.actions.openSystem = { XCTFail("the host opened \($0)") }
        controller.loadViewIfNeeded()
        let text = try XCTUnwrap(descendant(of: controller.frameView, identifier: "popupV3.el-text-full"))
        let tap = try XCTUnwrap(objc_getAssociatedObject(text, &PopupV3Tap.key) as? PopupV3Tap)
        tap.perform(Selector(("fire")))
        XCTAssertEqual(links, ["https://demo.rees46.ru/sale"])
        XCTAssertTrue(controller.isClosing)
        waitUntil(closed)
        XCTAssertEqual(events, ["click"])
    }

    func testOneModalSlotSharedWithLegacyPopups() {
        let slots = PopupV3Slots()
        var legacy = false
        slots.legacyOpen = { legacy }
        let modal = PopupV3(json: ["id": 1, "layout": "modal", "trigger_type": "manual"])!
        let other = PopupV3(json: ["id": 2, "layout": "fullscreen", "trigger_type": "manual"])!
        let top = PopupV3(json: ["id": 3, "layout": "banner", "placement": "top", "trigger_type": "manual"])!
        let top2 = PopupV3(json: ["id": 4, "layout": "banner", "placement": "top", "trigger_type": "manual"])!
        let bottom = PopupV3(json: ["id": 5, "layout": "banner", "placement": "bottom", "trigger_type": "manual"])!

        legacy = true
        XCTAssertFalse(slots.canOpen(modal).ok, "not over a legacy popup")
        XCTAssertTrue(slots.canOpen(top).ok, "a banner does not wait")
        legacy = false
        slots.reserve(modal)
        XCTAssertTrue(PopupV3Slots.isModalOpen, "legacy popups wait for it")
        XCTAssertFalse(slots.canOpen(other).ok)
        slots.reserve(top)
        XCTAssertFalse(slots.canOpen(top2).ok, "one banner at the top")
        XCTAssertTrue(slots.canOpen(bottom).ok)
        slots.release(modal)
        slots.release(top)
        XCTAssertFalse(PopupV3Slots.isModalOpen)
        XCTAssertTrue(slots.canOpen(other).ok)
        XCTAssertTrue(slots.canOpen(top2).ok)
    }

    // MARK: - Elements

    func testButtonsLinkCopyAndClose() throws {
        func tap(_ id: String) throws {
            let view = try XCTUnwrap(make("element-button", id))
            try XCTUnwrap(descendant(PopupV3ButtonControl.self, in: view)).sendActions(for: .touchUpInside)
        }
        try tap("el-btn-link")
        XCTAssertEqual(actions.events, ["click"])
        XCTAssertEqual(actions.opened, ["rees46demo://sale?from=ios"])
        try tap("el-btn-defaults")
        XCTAssertEqual(actions.events, ["click", "click"], "click without a link still counts")
        XCTAssertEqual(actions.opened.count, 1)
        try tap("el-btn-copy")
        XCTAssertEqual(actions.copied, ["SALE10"])
        try tap("el-btn-close")
        XCTAssertEqual(actions.closed, 1)
        XCTAssertEqual(actions.events.count, 3, "close is sent by the window, not as a click")
    }

    func testAFeedProductAndItsButtonClickThenGoToTheHost() throws {
        let view = try XCTUnwrap(make("element-recommendation", "el-rec"))
        let block = try XCTUnwrap(descendant(PersonalizationRecommenderBlock.self, in: view))
        let product = PersonalizationProduct(id: "42", name: "Mouse", price: "1", url: "https://demo.rees46.ru/p/42")
        block.onProductTap?(product)
        XCTAssertEqual(actions.events, ["click"])
        XCTAssertEqual(actions.products, ["42"])
        block.onProductAction?(product)
        XCTAssertEqual(actions.events, ["click", "click"], "the card's button acts as the card")
        XCTAssertEqual(actions.products, ["42", "42"])
        XCTAssertEqual(actions.opened, [], "the link is the actions' call")
    }

    func testCloseElementClosesAndALinkedTextOpens() throws {
        let close = try XCTUnwrap(make("element-close", "el-close-svg"))
        try XCTUnwrap(descendant(PopupV3CloseIcon.self, in: close)).sendActions(for: .touchUpInside)
        XCTAssertEqual(actions.closed, 1)
        let text = try XCTUnwrap(make("element-text", "el-text-full"))
        XCTAssertEqual(text.gestureRecognizers?.count, 1)
        XCTAssertNil(try XCTUnwrap(make("element-text", "el-text-bare")).gestureRecognizers)
    }

    func testEmailCollectorValidatesSubscribesAndThanks() throws {
        let view = try XCTUnwrap(make("element-email-collector", "el-email-inline") as? PopupV3EmailView)
        view.field.text = "demo+ios@rees46.test"
        view.send()
        XCTAssertEqual(view.errorText, "Проверьте email", "consent is required")
        XCTAssertTrue(actions.subscriptions.isEmpty)
        view.checkbox.checkState = .checked
        view.field.text = "not an email"
        view.send()
        XCTAssertEqual(view.errorText, "Проверьте email")
        view.field.text = " demo+ios@rees46.test "
        view.send()
        XCTAssertNil(view.errorText)
        XCTAssertEqual(actions.subscriptions.first?.email, "demo+ios@rees46.test")
        XCTAssertEqual(actions.subscriptions.first?.consents, ["email_bulk", "email_chain"])
        XCTAssertEqual(actions.segments, ["123"])
        XCTAssertEqual(actions.events, ["subscribe:email", "submit"])
        XCTAssertTrue(view.isShowingSuccess)
    }

    func testEmailCollectorNetworkErrorKeepsTheForm() throws {
        actions.succeeds = false
        let view = try XCTUnwrap(make("element-email-collector", "el-email-bare") as? PopupV3EmailView)
        view.checkbox.checkState = .checked
        view.field.text = "demo+ios@rees46.test"
        view.send()
        XCTAssertEqual(view.errorText, PopupV3Texts.ru.sendError)
        XCTAssertEqual(actions.subscriptions.first?.consents, ["email_bulk", "email_chain", "email_transactional"])
        XCTAssertTrue(actions.events.isEmpty)
        XCTAssertFalse(view.isShowingSuccess)
        XCTAssertFalse(view.isBusy, "another try is possible")
    }

    func testFormSendsTheProfileThenConsentAndSegment() throws {
        let view = try XCTUnwrap(make("element-form", "el-form") as? PopupV3FormView)
        view.send()
        XCTAssertEqual(view.errorText, "Заполните обязательные поля", "the email is required")
        let example = ((PopupsV3Fixtures.expect("element-form")["el-form"] as? [String: Any])?["submit"] as? [String: Any])?["profile_set_example"] as? [String: String] ?? [:]
        let byKey = Dictionary(uniqueKeysWithValues: view.inputs.map { ($0.field.profileKey, $0) })
        for (key, value) in example {
            let input = try XCTUnwrap(byKey[key], key)
            if input.field.kind == .birthday || input.field.kind == .gender { input.value = value } else { input.textField.text = value }
        }
        view.checkbox.checkState = .checked
        view.send()
        XCTAssertNil(view.errorText)
        XCTAssertEqual(actions.profiles, [PopupV3Profile(
            email: "anna@example.com", phone: "+79990000000", firstName: "Анна", lastName: "Иванова",
            birthday: "1990-04-12", gender: "f", custom: ["fav_color": "зелёный", "loyaltylevel": "gold"]
        )])
        XCTAssertEqual(actions.subscriptions.first?.consents, ["email_bulk"])
        XCTAssertEqual(actions.segments, ["456"])
        XCTAssertEqual(actions.events, ["submit"])
        XCTAssertTrue(view.isShowingSuccess)
    }

    func testFormRejectsABadPhone() throws {
        let view = try XCTUnwrap(make("element-form", "el-form") as? PopupV3FormView)
        view.inputs[0].textField.text = "anna@example.com"
        view.inputs[1].textField.text = "123"
        view.send()
        XCTAssertEqual(view.errorText, "Заполните обязательные поля")
        XCTAssertTrue(actions.profiles.isEmpty)
        XCTAssertEqual(PopupV3FormView.wireDate(Date(timeIntervalSince1970: 639_921_600)), "1990-04-12")
    }

    // MARK: - Consent checkbox

    private static let themes = [UITraitCollection(userInterfaceStyle: .light), UITraitCollection(userInterfaceStyle: .dark)]

    private func hex(_ color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let channel = { (value: CGFloat) in Int((value * 255).rounded()) }
        return String(format: "#%02x%02x%02x%02x", channel(red), channel(green), channel(blue), channel(alpha))
    }

    /// Empty: the field's fill and border; checked: the button's fill and text. The same in light and dark.
    private func assertFormColors(_ checkbox: PersonalizationCheckbox, checked: String, checkmark: String, unchecked: String, border: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let state = checkbox.checkState
        defer { checkbox.checkState = state }
        for traits in Self.themes {
            checkbox.checkState = .unchecked
            XCTAssertEqual(hex(checkbox.fillColor.resolvedColor(with: traits)), unchecked, file: file, line: line)
            XCTAssertEqual(hex(checkbox.borderColor.resolvedColor(with: traits)), border, file: file, line: line)
            checkbox.checkState = .checked
            XCTAssertEqual(hex(checkbox.fillColor.resolvedColor(with: traits)), checked, file: file, line: line)
            XCTAssertEqual(hex(checkbox.glyphColor.resolvedColor(with: traits)), checkmark, file: file, line: line)
        }
    }

    func testTheConsentCheckboxTakesTheFormColorsInAnyTheme() throws {
        // Nothing in the design: the defaults of the button and the field.
        for checkbox in [try XCTUnwrap(make("element-email-collector", "el-email-bare") as? PopupV3EmailView).checkbox,
                         try XCTUnwrap(make("element-form", "el-form-bare") as? PopupV3FormView).checkbox] {
            assertFormColors(checkbox, checked: "#2563ebff", checkmark: "#ffffffff", unchecked: "#f8fafcff", border: "#cbd5e1ff")
        }
        let inline = try XCTUnwrap(make("element-email-collector", "el-email-inline") as? PopupV3EmailView)
        assertFormColors(inline.checkbox, checked: "#2563ebff", checkmark: "#ffffffff", unchecked: "#ffffffff", border: "#cbd5e1ff")

        let button: [String: Any] = ["buttonBgColor": "#16a34a", "buttonTextColor": "#111827"]
        let email = try XCTUnwrap(PopupV3Elements.make(PopupV3Element(
            id: "email", type: "emailCollector",
            style: button.merging(["emailInputBg": "#fef3c7", "emailInputBorderColor": "#92400e"]) { $1 }
        ), context: context) as? PopupV3EmailView)
        assertFormColors(email.checkbox, checked: "#16a34aff", checkmark: "#111827ff", unchecked: "#fef3c7ff", border: "#92400eff")
        let form = try XCTUnwrap(PopupV3Elements.make(PopupV3Element(
            id: "form", type: "form",
            style: button.merging(["formInputBg": "#1e293b", "formInputBorderColor": "#334155", "formConsentLabel": "Согласен"]) { $1 }
        ), context: context) as? PopupV3FormView)
        assertFormColors(form.checkbox, checked: "#16a34aff", checkmark: "#111827ff", unchecked: "#1e293bff", border: "#334155ff")
    }

    func testTheKitCheckboxWithoutColorsKeepsItsTokens() {
        let checkbox = PersonalizationCheckbox()
        XCTAssertNil(checkbox.checkedColor)
        XCTAssertNil(checkbox.checkmarkColor)
        XCTAssertNil(checkbox.uncheckedColor)
        XCTAssertNil(checkbox.uncheckedBorderColor)
        for traits in Self.themes {
            checkbox.checkState = .unchecked
            checkbox.isEnabled = true
            XCTAssertEqual(hex(checkbox.fillColor.resolvedColor(with: traits)), hex(PersonalizationColor.backgroundInput.resolvedColor(with: traits)))
            XCTAssertEqual(hex(checkbox.borderColor.resolvedColor(with: traits)), hex(PersonalizationColor.lineInput.resolvedColor(with: traits)))
            checkbox.isEnabled = false
            XCTAssertEqual(hex(checkbox.fillColor.resolvedColor(with: traits)), hex(PersonalizationColor.backgroundInputDisabled.resolvedColor(with: traits)))
            checkbox.checkState = .checked
            XCTAssertEqual(hex(checkbox.fillColor.resolvedColor(with: traits)), hex(PersonalizationColor.buttonPrimaryDisabled.resolvedColor(with: traits)))
            checkbox.isEnabled = true
            XCTAssertEqual(hex(checkbox.fillColor.resolvedColor(with: traits)), hex(PersonalizationColor.buttonPrimary.resolvedColor(with: traits)))
            XCTAssertEqual(hex(checkbox.glyphColor.resolvedColor(with: traits)), hex(PersonalizationColor.textLightPrimary.resolvedColor(with: traits)))
        }
        // A disabled checkbox keeps the disabled tokens even with colors of its own.
        checkbox.checkedColor = .red
        checkbox.isEnabled = false
        let traits = Self.themes[0]
        XCTAssertEqual(hex(checkbox.fillColor.resolvedColor(with: traits)), hex(PersonalizationColor.buttonPrimaryDisabled.resolvedColor(with: traits)))
    }

    // MARK: - Kit components on the popup's background

    /// `root` in a window of the app's theme `style`, laid out, for the time of `body`.
    private func inWindow(_ style: UIUserInterfaceStyle, _ root: UIViewController, _ body: () throws -> Void) rethrows {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.overrideUserInterfaceStyle = style
        window.rootViewController = root
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        root.view.layoutIfNeeded()
        try body()
    }

    /// Popup 182 of the live list (a white modal with a recommender feed) under `frame`.
    private func live182(frame: [String: Any] = [:]) throws -> PopupV3ViewController {
        let list = PopupsV3List(payload: PopupsV3Fixtures.json("live-list-181-182")["payload"] as? [String: Any] ?? [:])
        let popup = try XCTUnwrap(list.popups.first { $0.id == 182 })
        var design = popup.design
        design["frameStyle"] = (design["frameStyle"] as? [String: Any] ?? [:]).merging(frame) { $1 }
        let presentation = PopupV3Presentation(popup: popup, design: PopupV3Design(json: design), runtime: [:], onEvent: { _, _ in }, onClose: {})
        return PopupV3ViewController(
            presentation: presentation,
            actions: PopupV3SDKActions(sdk: nil, appHost: "app.rees46.ru", linkHandler: nil, onEvent: { _, _ in }),
            hostStatusBar: nil
        )
    }

    func testTheFeedOfAWhitePopupIsLightInTheDarkTheme() throws {
        let controller = try live182()
        try inWindow(.dark, controller) {
            let block = try XCTUnwrap(descendant(PersonalizationRecommenderBlock.self, in: controller.frameView))
            XCTAssertEqual(block.traitCollection.userInterfaceStyle, .light, "the kit's text stays dark on the white frame")
            XCTAssertEqual(controller.frameView.traitCollection.userInterfaceStyle, .dark, "only the kit's view is set; the toast follows the app")
        }
        let light = try live182()
        try inWindow(.light, light) {
            let block = try XCTUnwrap(descendant(PersonalizationRecommenderBlock.self, in: light.frameView))
            XCTAssertEqual(block.traitCollection.userInterfaceStyle, .light, "as before in the light theme")
        }
    }

    func testTheFeedOnADarkBackgroundIsDark() throws {
        let controller = try live182(frame: ["bgColor": "#111827"])
        try inWindow(.light, controller) {
            let block = try XCTUnwrap(descendant(PersonalizationRecommenderBlock.self, in: controller.frameView))
            XCTAssertEqual(block.traitCollection.userInterfaceStyle, .dark, "a dark frame: the kit's light text")
        }
        let white = CSSColor.white, dark = try XCTUnwrap(CSSColor.parse("#0f172a"))
        XCTAssertEqual(PopupV3KitTheme.background(element: dark, frame: white), dark, "an element's own background first")
        XCTAssertEqual(PopupV3KitTheme.background(element: .transparent, frame: dark), dark, "then the frame's")
        XCTAssertEqual(PopupV3KitTheme.background(element: .transparent, frame: .transparent), white, "then white, as the frame is drawn by default")
        XCTAssertEqual(PopupV3KitTheme.style(on: dark), .dark)
        XCTAssertEqual(PopupV3KitTheme.style(on: white), .light)
        XCTAssertEqual(PopupV3KitTheme.style(on: try XCTUnwrap(CSSColor.parse("#fde68a"))), .light, "a pale brand color")
        XCTAssertEqual(PopupV3KitTheme.style(on: try XCTUnwrap(CSSColor.parse("#1d4ed8"))), .dark, "a deep brand color")
        XCTAssertEqual(CSSColor.black.contrast(with: .white), 21, accuracy: 0.01)
    }

    func testTheKitOutsidePopupsFollowsTheSystem() throws {
        let screen = UIViewController()
        let block = PersonalizationRecommenderBlock(code: "e4bceaa2a37cdc9f1d995b8862b4fe2a", layout: .carousel)
        screen.view.addSubview(block)
        try inWindow(.dark, screen) {
            XCTAssertEqual(block.overrideUserInterfaceStyle, .unspecified)
            XCTAssertEqual(block.traitCollection.userInterfaceStyle, .dark)
        }
    }

    func testPromoCodeCopiesThenOpensTheApplyLink() throws {
        let view = try XCTUnwrap(make("element-promo-code", "el-promo-personal", runtime: ["promo_code": "ABC123"]) as? PopupV3PromoView)
        XCTAssertEqual(view.codeLabel.attributedText?.string, "ABC123")
        view.copyCode()
        XCTAssertEqual(actions.copied, ["ABC123"])
        XCTAssertEqual(actions.events, ["click"])
        XCTAssertEqual(actions.opened, ["rees46demo://cart?promo=ABC123"])
        XCTAssertEqual(view.copyButton?.attributedTitle(for: .normal)?.string, "Скопировано!")
        let fixed = try XCTUnwrap(make("element-promo-code", "el-promo-static") as? PopupV3PromoView)
        XCTAssertNil(fixed.copyButton)
        XCTAssertEqual(fixed.codeLabel.attributedText?.string, "WELCOME5")
    }

    func testSurveyScaleCommentSendAndThanks() throws {
        let view = try XCTUnwrap(make("element-survey", "el-survey-nps") as? PopupV3SurveyView)
        XCTAssertEqual(view.scores.count, 11)
        XCTAssertFalse(view.isFormShown)
        view.send()
        XCTAssertTrue(actions.reviews.isEmpty, "no score yet")
        view.select(0)
        XCTAssertTrue(view.isFormShown)
        view.comment.text = "Долгая доставка"
        view.send()
        XCTAssertEqual(actions.reviews.first?.kind, .nps)
        XCTAssertEqual(actions.reviews.first?.body as NSDictionary?, ["channel": "popup", "category": "test", "rate": 0, "comment": "Долгая доставка"])
        XCTAssertEqual(actions.events, ["submit"])
        XCTAssertTrue(view.isShowingThanks)
    }

    func testSurveyErrorCanBeRetried() throws {
        actions.succeeds = false
        let view = try XCTUnwrap(make("element-survey", "el-survey-ces") as? PopupV3SurveyView)
        XCTAssertEqual(view.scores.count, 7)
        view.select(7)
        view.send()
        XCTAssertEqual(view.errorText, PopupV3Texts.ru.sendError)
        XCTAssertFalse(view.isShowingThanks)
        actions.succeeds = true
        view.send()
        XCTAssertEqual(actions.reviews.count, 2)
        XCTAssertTrue(view.isShowingThanks)
    }

    func testOverlineIsDrawnWithoutCrashing() {
        let label = PopupV3Label(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        label.attributedText = PopupV3Fonts.attributed(PopupV3Markup.spans("^^надчёркнутый^^ текст"), size: 16, weight: 400, family: nil, color: .black, lineHeight: 1.35)
        let image = UIGraphicsImageRenderer(size: label.bounds.size).image { context in label.layer.render(in: context.cgContext) }
        XCTAssertEqual(image.size, label.bounds.size)
    }
}
