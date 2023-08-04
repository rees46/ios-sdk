import Foundation

public protocol SdkConfigurationProtocol: AnyObject {
    func registerFont(fileName: String, fileExtension: String)
    func setStoriesBlock(fontName: String, fontSize: CGFloat, textColor: String, backgroundColor: String)
    func setSlideDefaultButton(fontName: String, fontSize: CGFloat, textColor: String, backgroundColor: String)
    func setSlideProductsButton(fontName: String, fontSize: CGFloat, textColor: String, backgroundColor: String)
    func setProductsCard(fontName: String)
    
    
    func sessionRegisterFont(fileName: String , fileExtension: String) -> SdkConfigurationProtocol
    func secret() -> SdkConfigurationProtocol
    var stories: SdkConfigurationProtocol? { get set }
}

public extension SdkConfigurationProtocol {
    
    func sessionRegisterFont(fileName: String , fileExtension: String) -> SdkConfigurationProtocol {
        return stories!
    }
    
    func secret() -> SdkConfigurationProtocol! {
        return stories
    }
    
    func sessionRegisterFont(fileName: String, fileExtension: String) {
        //
    }
    
}
