import Foundation
import UIKit

class SearchServiceImpl: SearchService {
    
    private var sdk: PersonalizationSDK?
    private var sessionQueue: SessionQueue
    
    init(sdk: PersonalizationSDK) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
    }
    
    private func configureSession(timeOut: Double?) {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = timeOut ?? 1
        sessionConfig.waitsForConnectivity = true
        sessionConfig.shouldUseExtendedBackgroundIdleMode = true
        sdk?.configureURLSession(configuration: sessionConfig)
    }
    
    private func getRequest(
        path: String,
        params: [String: String],
        completion: @escaping (Result<[String: Any], SDKError>) -> Void
    ) {
        sdk?.getRequest(path: path, params: params, false) { result in
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
        
        if let limit = limit {
            params["limit"] = String(limit)
        }
        if let offset = offset {
            params["offset"] = String(offset)
        }
        if let categoryLimit = categoryLimit {
            params["category_limit"] = String(categoryLimit)
        }
        if let brandLimit = brandLimit {
            params["brand_limit"] = String(brandLimit)
        }
        if let categories = categories {
            params["categories"] = categories.map { String($0) }.joined(separator: ",")
        }
        if let extended = extended {
            params["extended"] = extended
        }
        if let sortBy = sortBy {
            params["sort_by"] = sortBy
        }
        if let sortDir = sortDir {
            params["sort_dir"] = sortDir
        }
        if let locations = locations {
            params["locations"] = locations
        }
        if let brands = brands {
            params["brands"] = brands
        }
        if let filters = filters,
           let jsonData = try? JSONSerialization.data(withJSONObject: filters, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            params["filters"] = jsonString
        }
        if let priceMin = priceMin {
            params["price_min"] = String(priceMin)
        }
        if let priceMax = priceMax {
            params["price_max"] = String(priceMax)
        }
        if let colors = colors {
            params["colors"] = sdk?.generateString(array: colors) ?? ""
        }
        if let fashionSizes = fashionSizes {
            params["fashion_sizes"] = sdk?.generateString(array: fashionSizes) ?? ""
        }
        if let exclude = exclude {
            params["exclude"] = exclude
        }
        if let email = email {
            params["email"] = email
        }
        if let disableClarification = disableClarification, disableClarification {
            params["no_clarification"] = "1"
        }
        
        return params
    }
    
    func searchBlank(completion: @escaping (Result<SearchBlankResponse, SDKError>) -> Void) {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "search: SDK is not initialized")))
            return
        }
        
        sessionQueue.addOperation {
            let params: [String: String] = [
                "did": sdk.deviceId,
                "shop_id": sdk.shopId
            ]
            
            self.configureSession(timeOut: 1)
            self.getRequest(path: "search/blank", params: params) { (result: Result<[String: Any], SDKError>) in
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
        completion: @escaping (Result<SearchResponse, SDKError>) -> Void
    ) {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "search: SDK is not initialized")))
            return
        }
        
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
            
            self.configureSession(timeOut: timeOut)
            self.getRequest(path: "search", params: params) { (result: Result<[String: Any], SDKError>) in
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
