extension String?{
  func isValid(email: String?) -> Bool {
    
    let firstpart = "[A-Z0-9a-z]([A-Z0-9a-z._%+-]{0,30}[A-Z0-9a-z])?"
    let serverpart = "([A-Z0-9a-z]([A-Z0-9a-z-]{0,30}[A-Z0-9a-z])?\\.){1,6}"
    let emailRegex = firstpart + "@" + serverpart + "[A-Za-z]{2,6}"
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    
    if emailPredicate.evaluate(with: email){
      return true}
    else { return false }
  }
  
  
  
  func isValid(phone: String?) -> Bool {
    
    let phoneRegex = "^\\+[0-9]{1,4}[0-9]{10}$"
    let PhonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
    
    if PhonePredicate.evaluate(with: phone){
      return true}
    else { return false }
  }
}
