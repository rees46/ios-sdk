import Foundation

extension URLSessionConfiguration {
    /// A copy of the configuration that neither sends nor stores cookies. The API sets a `did` cookie
    /// on its domain for a year, and an `/init` without a `did` gets the cookie's back: through a cookie
    /// store, `deleteUserCredentials()` and `needReInitialization` would get the old did again, and a
    /// second shop the first one's. Every session of the SDK is made from such a copy, the app's
    /// configuration included; the app's object is left as it is.
    func withoutCookies() -> URLSessionConfiguration {
        let configuration = (copy() as? URLSessionConfiguration) ?? self
        configuration.turnCookiesOff()
        return configuration
    }

    /// Turns cookies off on this configuration itself: one the SDK made and does not want copied, a
    /// background one say.
    func turnCookiesOff() {
        httpShouldSetCookies = false
        httpCookieAcceptPolicy = .never
        httpCookieStorage = nil
    }
}

/// The SDK's stand-in for `URLSession.shared` on the API's requests that no instance's session
/// carries: a pending shop's push event on the old core, stories and popups v3. The default
/// configuration without cookies (`withoutCookies()`), made on first use.
enum SdkURLSession {

    private static let lock = NSLock()
    private static var session: URLSession?

    static var shared: URLSession {
        lock.lock(); defer { lock.unlock() }
        if let session = session {
            return session
        }
        let made = URLSession(configuration: URLSessionConfiguration.default.withoutCookies())
        session = made
        return made
    }

    /// Test-only: the next request makes the session again, from the `default` configuration of that
    /// moment — the stub server's while it is installed. The old one is not invalidated: a caller that
    /// has just taken it may still make a task on it.
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        session = nil
    }
}

extension URLSession {
    func dataTask(with url: URL, result: @escaping (Result<(URLResponse, Data), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: url) { data, response, error in
            if let error = error {
                result(.failure(error))
                return
            }
            guard let response = response, let data = data else {
                let error = NSError(domain: "error", code: 0, userInfo: nil)
                result(.failure(error))
                return
            }
            result(.success((response, data)))
        }
    }
    
    func postTask(with request: URLRequest, result: @escaping (Result<(URLResponse, Data), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: request) { data, response, error in
            if let error = error {
                result(.failure(error))
                return
            }
            guard let response = response, let data = data else {
                let error = NSError(domain: "error", code: 0, userInfo: nil)
                result(.failure(error))
                return
            }
            result(.success((response, data)))
        }
    }
}
