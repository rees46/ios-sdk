import Foundation

public typealias fontInstaller = SdkFontInstaller

public class SdkFontInstaller {
    
    public class func exchange(classMethod orginalSystemMethod: Selector, of originalSystemClass: AnyClass?, with customSystemMethod: Selector, of customSystemClass: AnyClass?) {
        
        guard let originalSystemMethod = class_getClassMethod(originalSystemClass, orginalSystemMethod) else {
            return assertionFailure("SDK: Original class method not found")
        }
        
        guard let customSystemMethod = class_getClassMethod(customSystemClass, customSystemMethod) else {
            return assertionFailure("SDK: Custom class method not found")
        }
        
        method_exchangeImplementations(originalSystemMethod, customSystemMethod)
    }
    
    
     public class func exchange(instanceMethod orginalSystemMethod: Selector, of originalSystemClass: AnyClass?, with customSystemMethod: Selector, of customSystemClass: AnyClass?) {

        guard let originalSystemMethod = class_getInstanceMethod(originalSystemClass, orginalSystemMethod) else {
            return assertionFailure("SDK: Original instance method not found")
        }
        
        guard let customSystemMethod = class_getInstanceMethod(customSystemClass, customSystemMethod) else {
            return assertionFailure("SDK: Custom instance method not found")
        }
        
        method_exchangeImplementations(originalSystemMethod, customSystemMethod)
    }
    
}
