import Foundation

protocol SearchServiceProtocol{
    
    func searchBlank(
        completion: @escaping (Result<SearchBlankResponse, SDKError>) -> Void
    )
    
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
    )
    
}
