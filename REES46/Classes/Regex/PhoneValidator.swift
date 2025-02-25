import Foundation
func isValid(phone:String) -> Bool {
  
  let phoneRegex = "^\\+?[0-9]{1,4}[\\s-]?\\(?[0-9]{3}\\)?[\\s-]?[0-9]{3}[\\s-]?[0-9]{2}[\\s-]?[0-9]{2}$"
  let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
  
  return phonePredicate.evaluate(with: phone)
}

