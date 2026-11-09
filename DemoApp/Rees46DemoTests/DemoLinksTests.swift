import XCTest

/// The demo's links (`DemoLinks`, compiled into this target as well): which links open the game,
/// which page the game screen loads, and that a stories link stays a stories link.
final class DemoLinksTests: XCTestCase {

    private func kind(_ link: String) -> DemoLinks.Kind {
        DemoLinks.kind(of: URL(string: link)!)
    }

    // MARK: - The game

    func testTheGameLinkOfEveryDemoOpensTheBuiltInGame() {
        for link in ["rees46://game", "rees46flutter://game", "rees46rn://game", "rees46://game/", "REES46://GAME"] {
            XCTAssertEqual(kind(link), .game(page: nil), link)
        }
        XCTAssertEqual(DemoLinks.game, "rees46://game")
    }

    func testOtherParametersDoNotMatter() {
        // A push adds its tracking to a link.
        XCTAssertEqual(kind("rees46://game?recommended_by=custom&mail_code=1"), .game(page: nil))
    }

    func testAnHttpsUrlParameterIsTheGamePage() {
        XCTAssertEqual(
            kind("rees46://game?url=https://games.example.com/memory"),
            .game(page: URL(string: "https://games.example.com/memory"))
        )
        // An encoded address keeps its own query.
        XCTAssertEqual(
            kind("rees46rn://game?url=https%3A%2F%2Fgames.example.com%2Fplay%3Fid%3D7%26lang%3Dru"),
            .game(page: URL(string: "https://games.example.com/play?id=7&lang=ru"))
        )
    }

    func testAnUrlThatIsNotHttpsOpensTheBuiltInGame() {
        for page in ["http://games.example.com", "javascript:alert(1)", "file:///etc/hosts", "rees46://game", "https://", "not a url", ""] {
            let encoded = page.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            XCTAssertEqual(kind("rees46://game?url=\(encoded)"), .game(page: nil), page)
        }
    }

    func testTheTextFormOfALink() {
        XCTAssertEqual(DemoLinks.kind(of: " rees46://game\n"), .game(page: nil))
        XCTAssertEqual(DemoLinks.kind(of: "https://demo.rees46.ru/product/1"), .other)
        XCTAssertEqual(DemoLinks.kind(of: ""), .other)
    }

    // MARK: - Stories and the rest

    func testALinkWithStoriesIsAStoriesLinkWhateverTheHost() {
        XCTAssertEqual(kind("rees46://game?r46_stories=272dd&r46_story=40"), .stories)
        XCTAssertEqual(kind("rees46://demo.rees46.ru/?r46_stories=272dd&r46_story=40&r46_slide=37"), .stories)
        XCTAssertEqual(kind("https://demo.rees46.ru/?r46_stories=272dd"), .stories)
    }

    func testOtherLinksAreNotTheGame() {
        for link in [
            "rees46://product/1",
            "rees46://demo.rees46.ru/game",
            "https://game",
            "https://demo.rees46.ru/game",
            "otherapp://game",
            "demo://game"
        ] {
            XCTAssertEqual(kind(link), .other, link)
        }
    }

    // MARK: - The page the screen loads

    private let builtIn = URL(fileURLWithPath: "/app/REES46Demo.app/tic-tac-toe.html")

    func testTheBuiltInPageGetsTheAppTheme() {
        XCTAssertEqual(
            DemoGamePage.address(page: nil, builtIn: builtIn, dark: true).absoluteString,
            "file:///app/REES46Demo.app/tic-tac-toe.html#dark"
        )
        XCTAssertEqual(
            DemoGamePage.address(page: nil, builtIn: builtIn, dark: false).absoluteString,
            "file:///app/REES46Demo.app/tic-tac-toe.html#light"
        )
    }

    func testAnAppPageLoadsAsItIs() {
        let page = URL(string: "https://games.example.com/play?id=7#start")!
        XCTAssertEqual(DemoGamePage.address(page: page, builtIn: builtIn, dark: true), page)
    }

    func testTheGameLinkToTheAddress() {
        guard case .game(let page) = kind("rees46://game?url=ftp://games.example.com") else {
            return XCTFail("not a game link")
        }
        XCTAssertEqual(DemoGamePage.address(page: page, builtIn: builtIn, dark: false).fragment, "light")
    }

    /// The page ships with the app the tests run in.
    func testTheBuiltInPageIsInTheApp() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: DemoGamePage.resource, withExtension: DemoGamePage.resourceExtension))
        let html = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(html.contains("setGameTheme"))
    }
}
