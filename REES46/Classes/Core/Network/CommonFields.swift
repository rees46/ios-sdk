//
//  CommonFields.swift
//  REES46
//

import Foundation

/// The fields every request of a shop carries (`sdk/core/network.md`): `shop_id`, `did`, `sid` and
/// `seance` with one value, `stream`, `segment`. The client adds them in one place — the query of a
/// `GET`, the body of a `POST` — where the caller left them out or empty.
struct CommonFields {
    let shopId: String
    let deviceId: String
    let sessionId: String
    let stream: String
    let segment: String

    /// A device id and a session, taken together.
    struct Identity: Equatable {
        let deviceId: String
        let sessionId: String
    }

    /// These fields with `identity` in place of the stored device id and session.
    func with(_ identity: Identity) -> CommonFields {
        CommonFields(shopId: shopId, deviceId: identity.deviceId, sessionId: identity.sessionId, stream: stream, segment: segment)
    }

    /// The values of the common fields for a request to `path` whose own fields are `own`. An empty
    /// value is not sent: the API reads an empty field as a wrong one.
    ///
    /// - `/init` gets only `shop_id` and `stream`: it builds its device and session fields itself
    ///   (`sdk/core/init.md`).
    /// - A request that names a customer with the shop's secret (`shop_secret`) keeps its own
    ///   identity: it gets no `did`, `sid` or `segment` of this device, which the API would prefer to
    ///   the customer the call asked about.
    /// - Any other request goes with the device id the shop has stored when the request is sent, not
    ///   the one its caller put in earlier: after `deleteUserCredentials` the deleted one must not go
    ///   out. The caller's stands only while the shop has none, as in the old core.
    /// - `onlyShop`: a server method of a namespace (`SecretQuery`) gets `shop_id` alone.
    func values(forPath path: String, own: [String: Any], onlyShop: Bool = false) -> [String: String?] {
        func present(_ key: String) -> String? {
            guard let value = own[key] else { return nil }
            let text = (value as? String) ?? "\(value)"
            return text.isEmpty ? nil : text
        }
        func nonEmpty(_ value: String) -> String? { value.isEmpty ? nil : value }

        // Typed first: assigned straight into `[String: String?]`, `a ?? b` would wrap `a` and never
        // reach `b`.
        let shop: String? = present("shop_id") ?? nonEmpty(shopId)
        guard !onlyShop else { return ["shop_id": shop] }
        let source: String? = present("stream") ?? nonEmpty(stream)
        var values: [String: String?] = ["shop_id": shop, "stream": source]
        guard path != "init", own["shop_secret"] == nil else { return values }

        // The events of pushes carry no session: the server does not read it there.
        let session: String? = EventQueue.sessionlessPaths.contains(path) ? nil : present("sid") ?? present("seance") ?? nonEmpty(sessionId)
        let device: String? = nonEmpty(deviceId) ?? present("did")
        let group: String? = present("segment") ?? nonEmpty(segment)
        values["did"] = .some(device)
        values["sid"] = .some(session)
        values["seance"] = .some(session)
        values["segment"] = .some(group)
        return values
    }

    /// `query` with the common fields filled in.
    func apply(to query: [String: String], path: String, onlyShop: Bool = false) -> [String: String] {
        var result = query
        for (key, value) in values(forPath: path, own: query, onlyShop: onlyShop) {
            result[key] = value
        }
        return result
    }

    /// `body` with the common fields filled in.
    func apply(to body: [String: Any], path: String, onlyShop: Bool = false) -> [String: Any] {
        var result = body
        for (key, value) in values(forPath: path, own: body, onlyShop: onlyShop) {
            if let value = value {
                result[key] = value
            } else {
                result.removeValue(forKey: key)
            }
        }
        return result
    }
}
