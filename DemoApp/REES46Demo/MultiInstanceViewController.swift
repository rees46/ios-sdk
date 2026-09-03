//
//  MultiInstanceViewController.swift
//  REES46Demo
//
//  Multi-instance demo (iOS-21): two shops live in one app, each resolved by `shopId` through the
//  public `Rees46` facade — no `globalSDK`. Every request an instance sends carries its own
//  shop_id/did, so the two sessions stay isolated. Mirror of the Android `MultiInstancePane`.
//

import UIKit
import REES46

final class MultiInstanceViewController: UIViewController {

    // Two real demo shops (parity with the Android demo's SHOP_ID / SHOP_ID_2).
    private let shopA = "357382bf66ac0ce2f1722677c59511"
    private let shopB = "4b464e7c386120d4b621bf7cb79293"
    private let storiesCodeA = "115bd0b67cf5989a1b60c841790b2af6"
    private let storiesCodeB = "3704bd6e8a1a9a6dc65b75a5f01e5c8d"

    private let cardA = SessionCardView(title: "Shop A (default)")
    private let cardB = SessionCardView(title: "Shop B")
    private let logView = UITextView()
    private var logLines: [String] = []
    private let maxLoggedEvents = 40

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Multi-instance"
        view.backgroundColor = .white
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(close)
        )

        buildLayout()

        // Both shops initialized at once, each with its own session and storage. Resolution below goes
        // through Rees46.instance(for:) — the host holds no SDK reference of its own.
        Rees46.initialize(Rees46Config(shopId: shopA, enableAutoPopupPresentation: false))
        Rees46.initialize(Rees46Config(shopId: shopB, enableAutoPopupPresentation: false))
        refreshSessions()
    }

    // MARK: - Layout

    private func buildLayout() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
        ])

        stack.addArrangedSubview(title("Two shops, one app"))
        stack.addArrangedSubview(subtitle("Both shops are initialized at once, each with its own session and storage. Actions below resolve instances by shopId through Rees46."))

        stack.addArrangedSubview(cardA)
        stack.addArrangedSubview(cardB)
        stack.addArrangedSubview(button("Refresh sessions", #selector(refreshSessions)))

        stack.addArrangedSubview(title("Fail-fast contracts"))
        stack.addArrangedSubview(button("instance() with 2 shops → ambiguous", #selector(tapAmbiguous)))
        stack.addArrangedSubview(button("instance(\"nope\") → unknown", #selector(tapUnknown)))

        stack.addArrangedSubview(title("Push routing (Rees46.handlePush)"))
        stack.addArrangedSubview(button("push shop_id=A", #selector(tapPushA)))
        stack.addArrangedSubview(button("push shop_id=B", #selector(tapPushB)))
        stack.addArrangedSubview(button("push shop_id=unknown", #selector(tapPushUnknown)))
        stack.addArrangedSubview(button("push (no shop_id)", #selector(tapPushNone)))

        stack.addArrangedSubview(title("Per-shop stories"))
        stack.addArrangedSubview(storiesView(shopId: shopA, code: storiesCodeA))
        stack.addArrangedSubview(storiesView(shopId: shopB, code: storiesCodeB))

        logView.isEditable = false
        logView.font = UIFont(name: "Menlo", size: 12) ?? .systemFont(ofSize: 12)
        logView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        logView.text = "Results of contract and push-routing actions appear here"
        logView.heightAnchor.constraint(equalToConstant: 160).isActive = true
        stack.addArrangedSubview(logView)
    }

    private func title(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 17)
        label.numberOfLines = 0
        return label
    }

    private func subtitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor.gray
        label.numberOfLines = 0
        return label
    }

    private func button(_ text: String, _ action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(text, for: .normal)
        btn.contentHorizontalAlignment = .leading
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func storiesView(shopId: String, code: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .white // stories label colors assume a light backdrop
        // No height of its own: the block sizes the container, so an empty one collapses with it.

        let stories = StoriesView()
        stories.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stories)
        NSLayoutConstraint.activate([
            stories.topAnchor.constraint(equalTo: container.topAnchor),
            stories.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stories.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stories.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        // iOS-13 overload: the widget resolves its own instance by shopId, no sdk passed in.
        stories.configure(shopId: shopId, mainVC: self, code: code)
        return container
    }

    // MARK: - Actions

    @objc private func refreshSessions() {
        cardA.update(session: session(for: shopA))
        cardB.update(session: session(for: shopB))
        log("refreshed sessions")
    }

    private func session(for shopId: String) -> (did: String, seance: String)? {
        guard let sdk = try? Rees46.instance(for: shopId) else { return nil }
        return (sdk.getDeviceId(), sdk.getSession())
    }

    @objc private func tapAmbiguous() { log(resolveLog { try Rees46.instance() }) }
    @objc private func tapUnknown() { log(resolveLog { try Rees46.instance(for: "nope") }) }

    @objc private func tapPushA() { routePush(shopId: shopA, note: "routes to A") }
    @objc private func tapPushB() { routePush(shopId: shopB, note: "routes to B") }
    @objc private func tapPushUnknown() { routePush(shopId: "unknown", note: "dropped (unknown shop)") }
    @objc private func tapPushNone() { routePush(shopId: nil, note: "dropped (2 shops live, ambiguous)") }

    private func routePush(shopId: String?, note: String) {
        var payload: [AnyHashable: Any] = ["type": "bulk", "id": "demo"]
        if let shopId = shopId { payload["shop_id"] = shopId }
        Rees46.handlePush(payload, event: .received)
        log("push shop_id=\(shopId ?? "—") → \(note)")
    }

    /// Runs a throwing resolve and turns the outcome (an instance or the fail-fast error) into a line.
    private func resolveLog(_ resolve: () throws -> PersonalizationSDK) -> String {
        do {
            let sdk = try resolve()
            return "resolved shop \(sdk.getShopId())"
        } catch {
            return "\((error as? LocalizedError)?.errorDescription ?? "\(error)")"
        }
    }

    private func log(_ message: String) {
        logLines.insert(message, at: 0)
        if logLines.count > maxLoggedEvents { logLines.removeLast() }
        logView.text = logLines.joined(separator: "\n")
    }

    @objc private func close() { dismiss(animated: true) }
}

/// A labelled did/seance readout for one shop.
final class SessionCardView: UIView {

    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        layer.cornerRadius = 8

        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 15)
        bodyLabel.font = UIFont(name: "Menlo", size: 12) ?? .systemFont(ofSize: 12)
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = UIColor.gray

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
        update(session: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(session: (did: String, seance: String)?) {
        if let session = session {
            bodyLabel.text = "did=\(session.did.isEmpty ? "resolving…" : session.did)\nseance=\(session.seance)"
        } else {
            bodyLabel.text = "resolving…"
        }
    }
}
