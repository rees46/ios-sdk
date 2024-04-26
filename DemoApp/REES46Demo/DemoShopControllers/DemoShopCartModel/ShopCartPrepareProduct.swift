import Foundation

struct ShopCartPrepareProduct {
    private(set) public var productId: String
    private(set) public var brandTitle: String
    private(set) public var title: String
    private(set) public var price: String
    
    private(set) public var priceNum: Double
    private(set) public var oldPrice: String
    private(set) public var description: String
    private(set) public var imageName: String
    private(set) public var imagesArray: [String]
    
    init(productId: String, brandTitle: String, title: String, price: String, priceNum: Double, oldPrice: String, description: String, mainImage: String, imagesArray: [String]) {
        
        self.productId = productId
        self.brandTitle = brandTitle
        self.title = title
        self.price = price
        self.priceNum = priceNum
        self.oldPrice = oldPrice
        self.description = description
        self.imageName = mainImage
        
        self.imagesArray = imagesArray
    }
}
