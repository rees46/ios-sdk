import XCTest
@testable import REES46

/// Offline checks of the `subscriptions/manage` request body, through `MockPersonalizationSDK`.
final class ManageSubscriptionParamsTests: XCTestCase {

    private static let channelKeys = [
        "telegram_bulk", "telegram_chain", "telegram_transactional",
        "whatsapp_bulk", "whatsapp_chain", "whatsapp_transactional",
        "max_bulk", "max_chain", "max_transactional",
        "wallet_bulk"
    ]

    private var sdk: MockPersonalizationSDK!
    private var service: SubscriptionServiceImpl!

    override func setUp() {
        super.setUp()
        sdk = MockPersonalizationSDK()
        service = SubscriptionServiceImpl(sdk: sdk)
    }

    override func tearDown() {
        service = nil
        sdk = nil
        super.tearDown()
    }

    func test_telegramWhatsappMaxAndWalletFlags_goUnderTheirKeys() {
        let done = expectation(description: "manageSubscription completion")

        service.manageSubscription(
            telegramBulk: true,
            telegramChain: false,
            telegramTransactional: true,
            whatsappBulk: false,
            whatsappChain: true,
            whatsappTransactional: false,
            maxBulk: true,
            maxChain: false,
            maxTransactional: true,
            walletBulk: false
        ) { result in
            if case .failure(let error) = result {
                XCTFail("Expected success, got \(error)")
            }
            done.fulfill()
        }

        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(sdk.postCallCount, 1)
        XCTAssertEqual(sdk.lastPostPath, "subscriptions/manage")
        let params = sdk.lastPostParams ?? [:]
        XCTAssertEqual(params["telegram_bulk"] as? Bool, true)
        XCTAssertEqual(params["telegram_chain"] as? Bool, false)
        XCTAssertEqual(params["telegram_transactional"] as? Bool, true)
        XCTAssertEqual(params["whatsapp_bulk"] as? Bool, false)
        XCTAssertEqual(params["whatsapp_chain"] as? Bool, true)
        XCTAssertEqual(params["whatsapp_transactional"] as? Bool, false)
        XCTAssertEqual(params["max_bulk"] as? Bool, true)
        XCTAssertEqual(params["max_chain"] as? Bool, false)
        XCTAssertEqual(params["max_transactional"] as? Bool, true)
        XCTAssertEqual(params["wallet_bulk"] as? Bool, false)
    }

    func test_channelFlagsLeftNil_areNotSent() {
        let done = expectation(description: "manageSubscription completion")

        service.manageSubscription(email: "user@example.com", emailBulk: true) { _ in
            done.fulfill()
        }

        waitForExpectations(timeout: 2.0)

        let params = sdk.lastPostParams ?? [:]
        XCTAssertEqual(params["email"] as? String, "user@example.com")
        XCTAssertEqual(params["email_bulk"] as? Bool, true)
        for key in Self.channelKeys {
            XCTAssertNil(params[key], "\(key) should not be sent when nil")
        }
    }

    func test_invalidEmail_failsOnce_andSendsNothing() {
        var results: [Result<Void, SdkError>] = []
        let calledAgain = expectation(description: "completion called a second time")
        calledAgain.isInverted = true

        service.manageSubscription(email: "not-an-email", telegramBulk: true) { result in
            results.append(result)
            if results.count > 1 { calledAgain.fulfill() }
        }

        wait(for: [calledAgain], timeout: 1.0)

        XCTAssertEqual(results.count, 1)
        guard case .failure(.custom(let message)) = results.first else {
            return XCTFail("Expected a validation failure, got \(String(describing: results.first))")
        }
        XCTAssertEqual(message, "manageSubscription: email is not valid")
        XCTAssertEqual(sdk.postCallCount, 0)
    }
}
