import Foundation

/// A phone number as people write it: an optional leading `+`, then digits that may be grouped with
/// spaces, dashes and parentheses, 7 to 15 digits in all — the bounds the server itself accepts
/// (ITU-T E.164). The grouping differs by country (`+375 29 123-45-67`, `+44 20 7946 0958`), so only
/// the characters and the digit count are checked; the server keeps the digits only.
func isValid(phone: String) -> Bool {
  let trimmed = phone.trimmingCharacters(in: .whitespaces)
  let body = trimmed.hasPrefix("+") ? trimmed.dropFirst() : Substring(trimmed)
  let allowed = CharacterSet(charactersIn: "0123456789 -()")
  guard !body.isEmpty, body.unicodeScalars.allSatisfy(allowed.contains) else { return false }
  let digits = body.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
  return (7...15).contains(digits)
}
