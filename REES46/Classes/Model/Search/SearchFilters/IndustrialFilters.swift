import Foundation

public struct IndustrialFilters {
  public var fashionSizes: [FashionSizes]
  public var fashionColors: [FashionColors]
  
  init(json: [String: Any]) {
    let sizes = json["fashion_sizes"] as? [[String: Any]] ?? []
    var fashionSizesTemp = [FashionSizes]()
    for item in sizes {
      fashionSizesTemp.append(FashionSizes(json: item))
    }
    fashionSizes = fashionSizesTemp
    
    let colors = json["colors"] as? [[String: Any]] ?? []
    var fashionColorsTemp = [FashionColors]()
    for item in colors {
      fashionColorsTemp.append(FashionColors(json: item))
    }
    fashionColors = fashionColorsTemp
  }
}
