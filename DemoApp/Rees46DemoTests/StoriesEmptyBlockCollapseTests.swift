import XCTest
@testable import REES46

/// Covers DEV-T-370: a stories block switched off in the dashboard loads without stories, and the
/// widget used to keep its 135pt row anyway — an empty gap between the header and the content
/// underneath it.
///
/// The block now collapses on its own, so these tests pin the three ways it gives the space back:
/// `isHidden`, a zero intrinsic height, and the height it actually gets laid out at inside a stack.
///
/// `FakeSDK` stands in for the backend and answers off the main queue like the real SDK, so the
/// hand-over from the load callback to the collection view — where an empty block used to trap on
/// the list index — is exercised here rather than against a live shop.
final class StoriesEmptyBlockCollapseTests: XCTestCase {

    // MARK: - Fixtures

    private func makeStoriesView() -> StoriesView {
        StoriesView(frame: CGRect(x: 0, y: 0, width: 300, height: StoriesView.defaultHeight))
    }

    private func storyContent(storyCount: Int) -> StoryContent {
        let stories: [[String: Any]] = (0..<storyCount).map { index in
            ["id": index + 1, "name": "story \(index + 1)", "slides": [[String: Any]]()]
        }
        return StoryContent(json: ["id": 1, "settings": [String: Any](), "stories": stories])
    }

    private func load(_ view: StoriesView, storyCount: Int) {
        load(view, result: .success(storyContent(storyCount: storyCount)))
    }

    private func loadFailure(_ view: StoriesView) {
        load(view, result: .failure(.networkOfflineError))
    }

    /// Runs a load through the fake SDK and returns once `StoriesView` has applied it on the main
    /// queue — the load hops there, so asserting right after `configure` would race it.
    private func load(_ view: StoriesView, result: Result<StoryContent, SdkError>) {
        let sdk = FakeSDK()
        sdk.storiesResult = result

        let loaded = expectation(description: "stories block load finished")
        view.onStoriesLoadComplete = { _ in loaded.fulfill() }
        view.configure(sdk: sdk, mainVC: UIViewController(), code: "stories_code")

        wait(for: [loaded], timeout: 2)
    }

    // MARK: - Tests

    /// While the block is still loading it shows its placeholder row, so it keeps its height.
    func testBlockKeepsItsHeightBeforeTheFirstLoad() {
        let view = makeStoriesView()

        XCTAssertTrue(view.hasStories)
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.intrinsicContentSize.height, StoriesView.defaultHeight)
    }

    func testEmptyBlockCollapses() {
        let view = makeStoriesView()

        load(view, storyCount: 0)

        XCTAssertFalse(view.hasStories)
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.intrinsicContentSize.height, 0)
    }

    func testBlockWithStoriesKeepsItsHeight() {
        let view = makeStoriesView()

        load(view, storyCount: 3)

        XCTAssertTrue(view.hasStories)
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.intrinsicContentSize.height, StoriesView.defaultHeight)
    }

    /// What the ticket is actually about: the space the block takes on the host screen. A host that
    /// lets the block size itself gets the row back once the block turns out to be empty.
    func testEmptyBlockTakesNoSpaceInAStack() {
        let view = makeStoriesView()
        let stack = UIStackView(arrangedSubviews: [view])
        stack.axis = .vertical

        XCTAssertEqual(fittingHeight(of: stack), StoriesView.defaultHeight)

        load(view, storyCount: 0)

        XCTAssertEqual(fittingHeight(of: stack), 0)
    }

    /// Height the host layout gives the stack — the block's own height plus nothing else, since the
    /// stack holds only the block.
    private func fittingHeight(of stack: UIStackView) -> CGFloat {
        stack.systemLayoutSizeFitting(
            CGSize(width: 320, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    /// A failed request has nothing to show either, and it used to leave the placeholder row
    /// shimmering on the screen for good, since nothing ever resolved it.
    func testFailedLoadCollapses() {
        let view = makeStoriesView()

        loadFailure(view)

        XCTAssertFalse(view.hasStories)
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.intrinsicContentSize.height, 0)
    }

    /// Reconfiguring reloads the block, so a collapse is never final: a host that retries after a
    /// failure, or switches to a code that has stories, gets the row back.
    func testReloadBringsACollapsedBlockBack() {
        let view = makeStoriesView()
        var reports: [Bool] = []
        view.onStoriesCollapse = { reports.append($0) }

        loadFailure(view)
        load(view, storyCount: 2)

        XCTAssertTrue(view.hasStories)
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.intrinsicContentSize.height, StoriesView.defaultHeight)
        XCTAssertEqual(reports, [true, false])
    }

    /// Only a collapsed block goes back to the placeholder row while it reloads: stories already on
    /// screen stay there until the new list arrives.
    func testReloadKeepsTheCurrentStoriesUntilTheNewOnesArrive() {
        let view = makeStoriesView()
        load(view, storyCount: 3)

        let sdk = FakeSDK()
        sdk.storiesResult = .success(storyContent(storyCount: 1))
        sdk.storiesResultDelay = 0.2

        let loaded = expectation(description: "stories block load finished")
        view.onStoriesLoadComplete = { _ in loaded.fulfill() }
        view.configure(sdk: sdk, mainVC: UIViewController(), code: "stories_code")

        assertDataSourceIsConsistent(view, expectedCount: 3) // the new list is still in flight
        XCTAssertTrue(view.hasStories)

        wait(for: [loaded], timeout: 2)

        assertDataSourceIsConsistent(view, expectedCount: 1)
    }

    /// Every index the data source reports has to be one it can build a cell for. The two used to
    /// disagree: the placeholder row asked for 4 cells of a list that had already come back empty,
    /// and the subscript trapped.
    func testDataSourceServesEveryIndexItReports() {
        let view = makeStoriesView()

        assertDataSourceIsConsistent(view, expectedCount: 4) // placeholders, nothing loaded yet

        load(view, storyCount: 0)
        assertDataSourceIsConsistent(view, expectedCount: 0)

        load(view, storyCount: 3)
        assertDataSourceIsConsistent(view, expectedCount: 3)
    }

    /// The same window from the other side: the block is on screen and laying out while the response
    /// is still travelling from the SDK's queue.
    func testLayoutDuringAnInFlightLoadIsSafe() {
        let view = makeStoriesView()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(view)
        window.isHidden = false
        window.layoutIfNeeded()

        let sdk = FakeSDK()
        sdk.storiesResult = .success(storyContent(storyCount: 0))
        sdk.storiesResultDelay = 0.2

        let loaded = expectation(description: "stories block load finished")
        view.onStoriesLoadComplete = { _ in loaded.fulfill() }
        view.configure(sdk: sdk, mainVC: UIViewController(), code: "stories_code")

        // Lay the block out across the hand-over instead of parking the main queue in `wait`.
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, view.hasStories {
            window.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        wait(for: [loaded], timeout: 2)
        window.layoutIfNeeded()

        XCTAssertFalse(view.hasStories)
        XCTAssertTrue(view.isHidden)
    }

    /// Hosts touch UIKit from these callbacks, and the result they follow arrives off the main queue.
    func testCallbacksArriveOnTheMainQueue() {
        let view = makeStoriesView()
        var collapseWasOnMain: Bool?
        var loadWasOnMain: Bool?
        view.onStoriesCollapse = { _ in collapseWasOnMain = Thread.isMainThread }

        let sdk = FakeSDK()
        sdk.storiesResult = .success(storyContent(storyCount: 0))

        let loaded = expectation(description: "stories block load finished")
        view.onStoriesLoadComplete = { _ in
            loadWasOnMain = Thread.isMainThread
            loaded.fulfill()
        }
        view.configure(sdk: sdk, mainVC: UIViewController(), code: "stories_code")

        wait(for: [loaded], timeout: 2)

        XCTAssertEqual(collapseWasOnMain, true)
        XCTAssertEqual(loadWasOnMain, true)
    }

    /// Asks the block for its item count and then for every cell that count promises, the way the
    /// collection view would.
    private func assertDataSourceIsConsistent(
        _ view: StoriesView,
        expectedCount: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let probe = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 300, height: StoriesView.defaultHeight),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        probe.register(
            StoriesCollectionViewPreviewCell.self,
            forCellWithReuseIdentifier: StoriesCollectionViewPreviewCell.cellId
        )
        probe.dataSource = view

        let count = view.collectionView(probe, numberOfItemsInSection: 0)
        XCTAssertEqual(count, expectedCount, file: file, line: line)

        for row in 0..<count {
            _ = view.collectionView(probe, cellForItemAt: IndexPath(row: row, section: 0))
        }
    }

    /// The callback is for hosts that pin the height themselves — they collapse their own layout
    /// from it. It reports the change, so a block that loads with stories never fires it.
    func testCollapseCallbackReportsTheEmptyBlockOnly() {
        let emptyBlock = makeStoriesView()
        var emptyBlockReports: [Bool] = []
        emptyBlock.onStoriesCollapse = { emptyBlockReports.append($0) }

        load(emptyBlock, storyCount: 0)

        XCTAssertEqual(emptyBlockReports, [true])

        let filledBlock = makeStoriesView()
        var filledBlockReports: [Bool] = []
        filledBlock.onStoriesCollapse = { filledBlockReports.append($0) }

        load(filledBlock, storyCount: 1)

        XCTAssertEqual(filledBlockReports, [])
    }
}
