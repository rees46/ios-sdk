import Foundation

/// Links that reach the demo — from outside (`application(_:open:options:)`, a push) or from a
/// popup's or a slide's button — sorted out in one place.
///
/// The game link is the demo's scheme with the host `game`: `rees46://game`. The Flutter and React
/// Native demos have schemes of their own (`rees46flutter`, `rees46rn`), and any of the three opens
/// the game here, so one link set up in a popup or a story works in every demo. With
/// `url=<https address>` the game screen loads that page instead of the built-in one — an app's
/// game from its own server. A link with `r46_stories` is a stories link whatever its scheme and
/// host (see `DemoStoriesLinks`).
enum DemoLinks {

    enum Kind: Equatable {
        /// The game: `page` — the `https` page of the `url` parameter; `nil` — the built-in game.
        case game(page: URL?)
        case stories
        case other
    }

    /// Schemes of the demo apps — this one first.
    static let schemes = ["rees46", "rees46flutter", "rees46rn"]
    static let gameHost = "game"
    /// The game link of this demo.
    static let game = "\(schemes[0])://\(gameHost)"

    static func kind(of url: URL) -> Kind {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if items.contains(where: { $0.name == "r46_stories" }) { return .stories }
        guard let scheme = url.scheme?.lowercased(), schemes.contains(scheme),
              url.host?.lowercased() == gameHost else { return .other }
        return .game(page: items.first { $0.name == "url" }?.value.flatMap(httpsPage))
    }

    /// The same for a link as text (the stories callbacks hand links over as strings).
    static func kind(of link: String) -> Kind {
        URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)).map { kind(of: $0) } ?? .other
    }

    /// An `https` address with a host; anything else — `nil`, and the built-in game opens.
    private static func httpsPage(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

/// The page of the game screen.
enum DemoGamePage {

    /// The built-in game, a copy of one page shared by the four demos, in the app's resources.
    static let resource = "tic-tac-toe"
    static let resourceExtension = "html"

    /// What the screen loads: an app's `https` page as it is; the built-in page with the app's
    /// theme in the fragment (`#dark` / `#light`), which the page reads before it draws.
    static func address(page: URL?, builtIn: URL, dark: Bool) -> URL {
        if let page { return page }
        var components = URLComponents(url: builtIn, resolvingAgainstBaseURL: false)
        components?.fragment = dark ? "dark" : "light"
        return components?.url ?? builtIn
    }
}
