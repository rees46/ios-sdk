import Fakery

class MockGenerator {
    private static let faker = Faker()
    
    static func generatePhoneNumber(prefix: String = "+7", length: Int = 10) -> String {
        let digits = (0..<length).map { _ in String(Int.random(in: 0...9)) }.joined()
        return prefix + digits
    }
    
    static func generateEmail() -> String {
        return faker.internet.email()
    }
}
