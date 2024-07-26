import Foundation

import Foundation
import UIKit

class SearchServiceImpl: SearchService {
    
    private var sdk: PersonalizationSDK?
    private var sessionQueue: SessionQueue
    
    init(sdk: PersonalizationSDK) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
    }
    
    func searchBlank(
        completion: @escaping (Result<SearchBlankResponse, SDKError>) -> Void
    ){
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "search: SDK is not initialized")))
            return
        }
        
        sessionQueue.addOperation {
            let path = "search/blank"
            let params: [String : String] = [
                "did": sdk.deviceId,
                "shop_id": sdk.shopId
            ]
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            sessionConfig.shouldUseExtendedBackgroundIdleMode = true
            sdk.configureURLSession(configuration: sessionConfig)
            sdk.getRequest(path: path, params: params, false) { (result) in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = SearchBlankResponse(json: resJSON)
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
        categories: String?,
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
    ){
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "search: SDK is not initialized")))
            return
        }
        
        sessionQueue.addOperation {
            let path = "search"
            var params: [String: String] = [
                "shop_id": sdk.shopId,
                "did": sdk.deviceId,
                "seance": sdk.userSeance,
                "sid": sdk.userSeance,
                "type": "full_search",
                "search_query": query,
                "segment": sdk.segment
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
                params["categories"] = categories
            }
            if let extended = extended {
                params["extended"] = extended
            }
            if let sortBy = sortBy {
                params["sort_by"] = String(sortBy)
            }
            if let sortDir = sortDir {
                params["sort_dir"] = String(sortDir)
            }
            if let locations = locations {
                params["locations"] = locations
            }
            if let brands = brands {
                params["brands"] = brands
            }
            if let filters = filters {
                if let theJSONData = try? JSONSerialization.data(
                    withJSONObject: filters,
                    options: []) {
                    let theJSONText = String(data: theJSONData,
                                             encoding: .utf8)
                    params["filters"] = theJSONText
                }
            }
            if let priceMin = priceMin {
                params["price_min"] = String(priceMin)
            }
            if let priceMax = priceMax {
                params["price_max"] = String(priceMax)
            }
            if let colors = colors {
                let colorsArray = sdk.generateString(array: colors)
                params["colors"] = colorsArray
            }
            if let fashionSizes = fashionSizes {
                let fashionSizesArray = sdk.generateString(array: fashionSizes)
                params["fashion_sizes"] = fashionSizesArray
            }
            if let exclude = exclude {
                params["exclude"] = exclude
            }
            if let email = email {
                params["email"] = email
            }
            if let disableClarification = disableClarification {
                if disableClarification == true {
                    params["no_clarification"] = "1"
                }
            }

            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = timeOut ?? 1
            sessionConfig.waitsForConnectivity = true
            sessionConfig.shouldUseExtendedBackgroundIdleMode = true
            sdk.configureURLSession(configuration: sessionConfig)
            sdk.getRequest(path: path, params: params, false) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = SearchResponse(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
}
