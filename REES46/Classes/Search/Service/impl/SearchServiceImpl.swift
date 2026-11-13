import Foundation
import UIKit

class SearchServiceImpl: SearchServiceProtocol {
    
    private var sdk: PersonalizationSDK?
    private var sessionQueue: SessionQueue
    
    init(sdk: PersonalizationSDK) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
    }
    
    private func getRequest(
        path: String,
        params: [String: String],
        timeout: TimeInterval?,
        completion: @escaping (Result<[String: Any], SdkError>) -> Void
    ) {
        sdk?.getRequest(path: path, params: params, timeout: timeout) { result in
            switch result {
            case let .success(successResult):
                completion(.success(successResult))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    private func createParameters(
        forSearch query: String,
        limit: Int?,
        offset: Int?,
        categoryLimit: Int?,
        brandLimit: Int?,
        categories: [Int]?,
        extended: String?,
        sortBy: String?,
        sortDir: String?,
        locations: String?,
        excludedMerchants: [String]?,
        excludedBrands: [String]?,
        brands: String?,
        filters: [String: Any]?,
        priceMin: Double?,
        priceMax: Double?,
        colors: [String]?,
        fashionSizes: [String]?,
        exclude: String?,
        email: String?,
        disableClarification: Bool?
    ) -> [String: String] {
        
        var params: [String: String] = [
            "shop_id": sdk?.shopId ?? "",
            "did": sdk?.deviceId ?? "",
            "seance": sdk?.userSeance ?? "",
            "sid": sdk?.userSeance ?? "",
            "type": "full_search",
            "search_query": query,
            "segment": sdk?.segment ?? ""
        ]
        
        let optionalParams: [String: String?] = [
            "limit": limit.map(String.init),
            "offset": offset.map(String.init),
            "category_limit": categoryLimit.map(String.init),
            "brand_limit": brandLimit.map(String.init),
            "categories": categories?.map(String.init).joined(separator: ","),
            "extended": extended,
            "sort_by": sortBy,
            "sort_dir": sortDir,
            "locations": locations,
            // The server splits on "," without trimming: a space would become part of the next value.
            "excluded_merchants": SearchFilterParams.excludedMerchants(excludedMerchants, locations: locations),
            "excluded_brands": excludedBrands?.joined(separator: ","),
            "brands": brands,
            "price_min": priceMin.map { String(describing: $0) },
            "price_max": priceMax.map { String(describing: $0) },
            "colors": sdk?.generateString(array: colors ?? []),
            "fashion_sizes": sdk?.generateString(array: fashionSizes ?? []),
            "exclude": exclude,
            "email": email,
            "no_clarification": disableClarification == true ? "1" : nil,
            "filters": {
                guard let filters = filters,
                      let jsonData = try? JSONSerialization.data(withJSONObject: filters, options: []),
                      let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
                return jsonString
            }()
        ]
        
        params.merge(optionalParams.compactMapValues { $0 }) { _, new in new }
        
        return params
    }
    
    func searchBlank(completion: @escaping (Result<SearchBlankResponse, SdkError>) -> Void) {
        guard let sdk = sdk.checkInitialization(completion: completion) else { return }
        
        sessionQueue.addOperation {
            let params: [String: String] = [
                "did": sdk.deviceId,
                "shop_id": sdk.shopId
            ]
            
            self.getRequest(path: "search/blank", params: params, timeout: 1) { (result: Result<[String: Any], SdkError>) in
                switch result {
                case let .success(successResult):
                    let resultResponse = SearchBlankResponse(json: successResult)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func search(
        query: String,
        limit: Int?,
        offset: Int?,
        categoryLimit: Int?,
        brandLimit: Int?,
        categories: [Int]?,
        extended: String?,
        sortBy: String?,
        sortDir: String?,
        locations: String?,
        excludedMerchants: [String]?,
        excludedBrands: [String]?,
        brands: String?,
        filters: [String: Any]?,
        priceMin: Double?,
        priceMax: Double?,
        colors: [String]?,
        fashionSizes: [String]?,
        exclude: String?,
        email: String?,
        timeOut: Double?,
        disableClarification: Bool?,
        completion: @escaping (Result<SearchResponse, SdkError>) -> Void
    ) {
        guard let sdk = sdk.checkInitialization(completion: completion) else { return }
        
        sessionQueue.addOperation {
            let params = self.createParameters(
                forSearch: query,
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
                excludedBrands: excludedBrands,
                brands: brands,
                filters: filters,
                priceMin: priceMin,
                priceMax: priceMax,
                colors: colors,
                fashionSizes: fashionSizes,
                exclude: exclude,
                email: email,
                disableClarification: disableClarification
            )
            
            self.getRequest(path: "search", params: params, timeout: timeOut ?? 1) { (result: Result<[String: Any], SdkError>) in
                switch result {
                case let .success(json):
                    let resultResponse = SearchResponse(json: json)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
}

/// Search filters as the server reads them, shared by full and instant search.
enum SearchFilterParams {
    /// `excluded_merchants`, or `nil` when it must not go. The server filters merchants inside the
    /// given locations: without locations — or with an empty list of them — the filter matches no
    /// product and the search finds nothing. Values are joined without spaces, as the server splits
    /// on "," without trimming.
    static func excludedMerchants(_ merchants: [String]?, locations: String?) -> String? {
        guard let merchants = merchants,
              let locations = locations,
              !locations.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return merchants.joined(separator: ",")
    }
}
