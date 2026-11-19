final class ContactValidator {

    typealias ValidationCompletion = (Result<[String: String], ValidationError>) -> Void

    func validate(email: String?, phone: String?, completion: ValidationCompletion) {
        var validatedParams: [String: String] = [:]

        // The server checks the format of an email (`sdk/contract/subscriptions.md`): only an empty one
        // is refused here.
        if let email = email {
            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                completion(.failure(.invalidEmail))
                return
            }
            validatedParams[Constants.email] = email
        }

        if let phone = phone {
            guard isValid(phone: phone) else {
                completion(.failure(.invalidPhone))
                return
            }
            validatedParams[Constants.phone] = phone
        }

        completion(.success(validatedParams))
    }

    private struct Constants {
        static let email = "email"
        static let phone = "phone"
    }
}
