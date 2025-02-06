func isValid(email:String) -> Bool {
  
  let firstpart = "[A-Z0-9a-z]([A-Z0-9a-z._%+-]{0,30}[A-Z0-9a-z])?"
  let serverpart = "([A-Z0-9a-z]([A-Z0-9a-z-]{0,30}[A-Z0-9a-z])?\\.){1,6}"
  let emailRegex = firstpart + "@" + serverpart + "[A-Za-z]{2,63}"
  let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
  
  return emailPredicate.evaluate(with:email)
}


