//
//  SlidersAPIImpl.swift
//  REES46
//

import Foundation

struct SlidersAPIImpl: SlidersAPI {

    let requests: NamespaceRequests

    func get(code: String, tags: [String]?, locationId: String?, completion: @escaping (Result<Slider, Rees46.SdkError>) -> Void) {
        requests.call("sliders.get", completion: completion) { try Self.getRequest(code: code, tags: tags, locationId: locationId) }
    }

    func get(code: String, tags: [String]?, locationId: String?) async throws -> Slider {
        try await requests.value("sliders.get") { try Self.getRequest(code: code, tags: tags, locationId: locationId) }
    }

    /// `GET slider` for the customer of the device id: the tags joined by commas, the location as
    /// `location`. No contacts: the device id is the customer, a contact goes to it through `profile`.
    static func getRequest(code: String, tags: [String]?, locationId: String?) throws -> ApiRequest<Slider> {
        guard !isBlank(code) else {
            throw Rees46.SdkError.invalidArgument("the code of the slider must not be empty")
        }
        if tags?.contains(where: { isBlank($0) || $0.contains(",") }) == true {
            throw Rees46.SdkError.invalidArgument("a tag must not be empty or have a comma")
        }
        var query = ["code": code]
        if let tags = tags, !tags.isEmpty {
            query["tags"] = tags.joined(separator: ",")
        }
        if let location = locationId, !isBlank(location) {
            query["location"] = location
        }
        return .get("slider", query: query, answer: SliderAnswer.self) { $0.slider }
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// `{"status": "success", "payload": {"properties": {"code", "width", "height"}, "slides": [...]}}`: the
/// banners are `payload.slides`. A banner without a `banner_id` cannot be tracked and is left out; one
/// without a `recommended_code` takes the slider's. `content_type` and `content` are the server's own.
/// Without `payload` it is not a slider (`decoding`).
struct SliderAnswer: Decodable {

    let slider: Slider

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnswerKey.self)
        guard let payload = try? root.nestedContainer(keyedBy: AnswerKey.self, forKey: "payload") else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "no payload"))
        }
        let properties = try? payload.nestedContainer(keyedBy: AnswerKey.self, forKey: "properties")
        let code = properties?.lenientString("code") ?? ""
        slider = Slider(
            code: code,
            width: properties?.lenientInt("width") ?? 0,
            height: properties?.lenientInt("height") ?? 0,
            banners: (payload.lenientList(BannerAnswer.self, "slides") ?? []).map { $0.banner(of: code) }
        )
    }

    private struct BannerAnswer: Decodable {
        let id: String
        let code: String?
        let imageUrl: String?
        let url: String?
        let deeplinkIos: String?
        let deeplinkAndroid: String?
        let html: String?

        init(from decoder: Decoder) throws {
            let item = try decoder.container(keyedBy: AnswerKey.self)
            guard let id = item.lenientString("banner_id") else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "no banner_id"))
            }
            self.id = id
            code = item.lenientString("recommended_code")
            imageUrl = item.lenientString("image_url")
            url = item.lenientString("url")
            deeplinkIos = item.lenientString("deeplink_ios")
            deeplinkAndroid = item.lenientString("deeplink_android")
            html = item.lenientString("html")
        }

        func banner(of slider: String) -> SliderBanner {
            SliderBanner(
                id: id, code: code ?? slider, imageUrl: imageUrl, url: url,
                deeplinkIos: deeplinkIos, deeplinkAndroid: deeplinkAndroid, html: html
            )
        }
    }
}
