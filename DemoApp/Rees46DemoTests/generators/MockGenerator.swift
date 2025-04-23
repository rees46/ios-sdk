import Fakery

class MockGenerator {
    private static let faker = Faker()
    
    static func generatePhoneNumber(prefix: String = Constants.phonePrefix, length: Int = Constants.phoneLength) -> String {
        let digits = (0..<length).map { _ in String(Int.random(in: 0...9)) }.joined()
        let phone = prefix + digits
        return phone
    }
    
    static func generateEmail() -> String {
        return faker.internet.email()
    }
}
