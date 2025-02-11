import Foundation

public struct IndustrialFilters: Codable {
  public var fashionSizes: [FashionSizes]
  public var fashionColors: [FashionColors]
  
  private enum CodingKeys: String, CodingKey {
    case fashionSizes = "fashion_sizes"
    case fashionColors = "colors"
  }

  public init(from decoder: Decoder) throws {
       let container = try decoder.container(keyedBy: CodingKeys.self)

       fashionSizes = try container.decode([FashionSizes].self, forKey: .fashionSizes)
       fashionColors = try container.decode([FashionColors].self, forKey: .fashionColors)
   }
}



