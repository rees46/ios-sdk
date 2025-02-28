import XCTest
@testable import REES46

class SearchServiceImplTests: XCTestCase {

    var sdk: PersonalizationSDK!
    
    let shopId = "693ff081028570920fd8a6b971eb5e"

    override func setUp() {
        super.setUp()
        sdk = createPersonalizationSDK(
            shopId: shopId,
            apiDomain: "api-r46.halykmarket.kz",
            parentViewController: nil
        )
    }
    
    override func tearDown() {
        sdk = nil
        super.tearDown()
    }
    
    func testSearch_withoutLocations_withExcludedMerchants(){
        var productsTotalWithLocation: Int?
        var productsTotalWithoutLocation: Int?
        
        sdk?.search(
            query: "пудра-бронзер"
        ) { result in
            switch result {
            case .success(let response):
                productsTotalWithLocation = response.productsTotal
            case .failure(let error):
                XCTFail("Search failed with error: \(error)")
            }
        }
        
        sdk?.search(
            query: "пудра-бронзер",
            excludedMerchants: ["Essa cosmetics"]
        ) { result in
            switch result {
            case .success(let response):
                productsTotalWithoutLocation = response.productsTotal
            case .failure(let error):
                XCTFail("Search failed with error: \(error)")
            }
        }
        
        XCTAssertEqual(productsTotalWithLocation, productsTotalWithoutLocation)
        
    }
    
    func testSearch_withExcludeBrands() {
        let expectation1 = XCTestExpectation(description: "First search completes")
        let expectation2 = XCTestExpectation(description: "Second search completes")
        
        var productsTotalWithBrands: Int?
        var productsTotalWithoutBrands: Int?
        
        sdk?.search(
            query: "пудра-бронзер"
        ) { result in
            switch result {
            case .success(let response):
                productsTotalWithBrands = response.productsTotal
                expectation1.fulfill()
            case .failure(let error):
                XCTFail("Search failed with error: \(error)")
            }
        }
        
        sdk?.search(
            query: "пудра-бронзер",
            excludedBrands: ["dior","estee lauder"]
        ) { result in
            switch result {
            case .success(let response):
                productsTotalWithoutBrands = response.productsTotal
                expectation2.fulfill()
            case .failure(let error):
                XCTFail("Search failed with error: \(error)")
            }
        }
        wait(for: [expectation1, expectation2], timeout: 10)
        XCTAssertNotEqual(productsTotalWithBrands, productsTotalWithoutBrands)
    }
    
    func testSuggest_withExcludeBrands() {
        let expectation1 = XCTestExpectation(description: "First search completes")
        let expectation2 = XCTestExpectation(description: "Second search completes")
        
        var productsTotalWithBrands: Int?
        var productsTotalWithoutBrands: Int?
        
        sdk?.suggest(
            query: "пудра-бронзер"
        ) { result in
            switch result {
            case .success(let response):
                productsTotalWithBrands = response.productsTotal
                expectation1.fulfill()
            case .failure(let error):
                XCTFail("Search failed with error: \(error)")
            }
        }
        
        sdk?.suggest(
            query: "пудра-бронзер",
            excludedBrands: ["dior","estee lauder"]
        ) { result in
            switch result {
            case .success(let response):
                productsTotalWithoutBrands = response.productsTotal
                expectation2.fulfill()
            case .failure(let error):
                XCTFail("Search failed with error: \(error)")
            }
        }
        wait(for: [expectation1, expectation2], timeout: 10)
        XCTAssertNotEqual(productsTotalWithBrands, productsTotalWithoutBrands)
    }
    
    func testSearch_withAllFields() {
        let query = "test search query"
        let limit = 10
        let offset = 20
        let categoryLimit = 5
        let brandLimit = 5
        let categories = [1, 2, 3]
        let extended = "extended_value"
        let sortBy = "price"
        let sortDir = "asc"
        let locations = "-1"
        let excludedMerchants = ["Essa cosmetics"]
        let brands = "brand1"
        let filters: [String: Any] = ["bluetooth":"yes"]
        let priceMin: Double = 100.0
        let priceMax: Double = 500.0
        let colors = ["red", "blue"]
        let fashionSizes = ["42"]
        let exclude = "exclude_value"
        let email = "test@example.com"
        let disableClarification = true
        
        let expectation = self.expectation(description: "search completion")
        
        sdk?.search(
            query: query,
            limit: limit,
            offset: offset,
            categoryLimit: categoryLimit,
            brandLimit: brandLimit,
            categories: categories,
            extended: extended,
            sortBy: sortBy,
            sortDir: sortDir,
            locations: locations,
            excludedMerchants: excludedMerchants,
            brands: brands,
            filters: filters,
            priceMin: priceMin,
            priceMax: priceMax,
            colors: colors,
            fashionSizes: fashionSizes,
            exclude: exclude,
            email: email,
            timeOut: nil,
            disableClarification: disableClarification
        ) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTFail("Search failed with error: \(error)")
            }
            expectation.fulfill()
        }
    
        waitForExpectations(timeout: 5, handler: nil)
    }

    func testSearch_withMinimalFields() {
        let query = "minimal query"
        
        let expectation = self.expectation(description: "search completion")
        
        sdk?.search(
            query: query,
            limit: nil,
            offset: nil,
            categoryLimit: nil,
            brandLimit: nil,
            categories: nil,
            extended: nil,
            sortBy: nil,
            sortDir: nil,
            locations: nil,
            excludedMerchants: nil,
            brands: nil,
            filters: nil,
            priceMin: nil,
            priceMax: nil,
            colors: nil,
            fashionSizes: nil,
            exclude: nil,
            email: nil,
            timeOut: nil,
            disableClarification: nil
        ) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTFail("Search failed with error: \(error)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
}
