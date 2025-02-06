func isValid(email:String) -> Bool {
  
  let firstpart = "[A-Z0-9a-z]([A-Z0-9a-z._%+-]{0,30}[A-Z0-9a-z])?"
  let serverpart = "([A-Z0-9a-z]([A-Z0-9a-z-]{0,30}[A-Z0-9a-z])?\\.){1,6}"
  let emailRegex = firstpart + "@" + serverpart + "[A-Za-z]{2,63}"
  let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
  
  return emailPredicate.evaluate(with:email)
}

func isValid(phone:String) -> Bool {
  
  let phoneRegex = "^\\+?[0-9]{1,4}[\\s-]?\\(?[0-9]{3}\\)?[\\s-]?[0-9]{3}[\\s-]?[0-9]{2}[\\s-]?[0-9]{2}$"
  let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
  
  return phonePredicate.evaluate(with: phone)
}

