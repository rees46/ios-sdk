import UIKit
@_spi(PersonalizationV3) import REES46

/// "Stories V2 polls (offline)": every kind of poll on Stories V2 slides without a set-up shop.
///
/// The campaign comes from `StoriesPollsFixture.json` (a v3 feed: single and multiple choice,
/// text, NPS, CSAT, CES, an answered poll with results and an unknown kind that is not drawn).
/// It is opened the way a host opens any block — `PersonalizationStories.show` on API v3 —
/// with a fake v3 host served by `DemoPollsFeedProtocol` and a fake polls transport
/// (`DemoPollTransport`): answers come back in 600 ms, mini polls with results, the text poll
/// fails once so the error and the retry can be seen. Nothing goes to the network but images.
enum DemoStoriesPolls {

    /// The fake API v3 host: `DemoPollsFeedProtocol` answers it from the bundled fixture.
    static let host = "polls.offline.demo"
    static let code = "polls-offline"

    static func exhibit() -> UIView {
        DemoPollsExhibit()
    }

    static func open(from presenter: UIViewController?) {
        DemoPollsFeedProtocol.register()
        PersonalizationStories.show(
            code: code,
            shopId: AppEnvironments.shopId,
            apiV3Domain: host,
            from: presenter,
            pollTransport: DemoPollTransport(),
            onError: { PersonalizationToast.show("Polls: \($0)") },
            onClose: { PersonalizationToast.show("Stories closed", position: .top) }
        )
    }
}

/// The answers a server would give, 600 ms later. Mini polls with `show_results` get results
/// (the picked options get the bigger shares, 100% in total); `demo_text` fails the first time
/// and goes through after; scales always go through.
final class DemoPollTransport: PersonalizationStoryPollTransport {

    static let delay: TimeInterval = 0.6
    private var textAttempts = 0
    private let polls = DemoPollsFeedProtocol.miniPolls()

    func answerMiniPoll(
        code: String,
        body: [String: Any],
        completion: @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void
    ) {
        let ids = body["option_ids"] as? [Int] ?? []
        let text = body["text"] as? String
        let outcome: Result<PersonalizationStoryPoll.Reply, Error>
        if code == "demo_text", textAttempts == 0 {
            textAttempts += 1
            outcome = .failure(URLError(.timedOut))
        } else {
            let poll = polls[code]
            let results = poll.flatMap { $0.showResults && !ids.isEmpty ? Self.results(options: $0.options, picked: ids) : nil }
            outcome = .success(.init(answer: .init(optionIds: ids.isEmpty ? nil : ids, text: text), results: results))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay) { completion(outcome) }
    }

    func review(
        kind: PersonalizationStoryPoll.Scale,
        body: [String: Any],
        completion: @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay) { completion(.success(.init())) }
    }

    /// Shares by weight — a picked option 3, the rest 1 — rounded to 100 in total.
    static func results(options: [Int], picked: [Int]) -> PersonalizationStoryPoll.Results {
        let weights = options.map { picked.contains($0) ? 3.0 : 1.0 }
        let sum = weights.reduce(0, +)
        var percents = weights.map { Int((100 * $0 / sum).rounded()) }
        if let top = percents.indices.max(by: { percents[$0] < percents[$1] }) {
            percents[top] += 100 - percents.reduce(0, +)
        }
        return .init(total: 120 + picked.count, options: zip(options, percents).map { .init(id: $0, percent: Double($1)) })
    }
}

/// Serves the fake v3 host: the block (and any campaign of it) is the bundled fixture, events
/// are accepted.
final class DemoPollsFeedProtocol: URLProtocol {

    private static let registration: Void = { URLProtocol.registerClass(DemoPollsFeedProtocol.self) }()

    static func register() {
        _ = registration
    }

    static var fixture: Data? {
        Bundle.main.url(forResource: "StoriesPollsFixture", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }

    /// Mini polls of the fixture: code → whether results are shown, option ids.
    static func miniPolls() -> [String: (showResults: Bool, options: [Int])] {
        guard let data = fixture,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stories = (json["payload"] as? [String: Any])?["stories"] as? [[String: Any]] else { return [:] }
        var polls: [String: (showResults: Bool, options: [Int])] = [:]
        for story in stories {
            for slide in story["slides"] as? [[String: Any]] ?? [] {
                for element in slide["elements"] as? [[String: Any]] ?? [] {
                    guard let poll = element["poll"] as? [String: Any], let code = poll["code"] as? String else { continue }
                    let options = (poll["options"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? Int }
                    polls[code] = (poll["show_results"] as? Bool ?? false, options)
                }
            }
        }
        return polls
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == DemoStoriesPolls.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let data = request.httpMethod == "POST" ? Data(#"{"status":"success"}"#.utf8) : Self.fixture
        guard let url = request.url, let data,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// The button of the showcase row.
private final class DemoPollsExhibit: UIStackView {

    init() {
        super.init(frame: .zero)
        axis = .vertical
        alignment = .leading
        spacing = 4
        let open = PersonalizationButton(text: "Stories V2 polls (offline)", size: .md, view: .primary)
        open.addTarget(self, action: #selector(openTapped), for: .touchUpInside)
        let caption = UILabel()
        caption.text = "A v3 feed from a fixture, a fake transport: answers in 600 ms, results for mini polls, the text poll fails once."
        caption.font = .preferredFont(forTextStyle: .caption1)
        caption.textColor = .secondaryLabel
        caption.numberOfLines = 0
        addArrangedSubview(open)
        addArrangedSubview(caption)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func openTapped() {
        var responder: UIResponder? = self
        while let current = responder, !(current is UIViewController) { responder = current.next }
        DemoStoriesPolls.open(from: responder as? UIViewController)
    }
}
