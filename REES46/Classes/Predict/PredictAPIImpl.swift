//
//  PredictAPIImpl.swift
//  REES46
//

import Foundation

struct PredictAPIImpl: PredictAPI {

    let requests: NamespaceRequests

    func getProbabilityToPurchase(completion: @escaping (Result<PurchaseProbability, Rees46.SdkError>) -> Void) {
        requests.call("predict.getProbabilityToPurchase", completion: completion) { Self.probabilityRequest }
    }

    func getProbabilityToPurchase() async throws -> PurchaseProbability {
        try await requests.value("predict.getProbabilityToPurchase") { Self.probabilityRequest }
    }

    /// `GET api/v3/cdp/users/probability-to-purchase` on `appDomain`, with nothing but the common fields:
    /// the server finds the customer by the device id, which wins over any contact (question 44 of
    /// `sdk/questions.md`), so none is sent. The API host's `predict/probability-to-purchase` answers
    /// `503`: its service is no longer deployed there (question 42). The general read timeout, not the 15
    /// seconds of the old method.
    static var probabilityRequest: ApiRequest<PurchaseProbability> {
        var request = ApiRequest<PurchaseProbability>.get(probabilityPath, answer: ProbabilityAnswer.self) { $0.value }
        request.host = .app
        return request
    }

    /// The path of the forecast on the host of API v3.
    static let probabilityPath = "api/v3/cdp/users/probability-to-purchase"
}

/// `{"status": "success", "payload": {"probability": 0.42, "client_id": 12345}}`: a `client_id` that is
/// `null` or missing is no customer, a success. Without a numeric `payload.probability` it is not a
/// forecast (`decoding`).
struct ProbabilityAnswer: Decodable {

    let value: PurchaseProbability

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnswerKey.self)
        let payload = try? root.nestedContainer(keyedBy: AnswerKey.self, forKey: "payload")
        guard let probability = payload?.lenientDouble("probability") else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "no numeric payload.probability"
            ))
        }
        value = PurchaseProbability(probability: probability, clientId: payload?.lenientString("client_id"))
    }

    /// The forecast in an answer the old methods got as JSON; `nil` when it is none.
    static func forecast(in json: Any) -> PurchaseProbability? {
        guard JSONSerialization.isValidJSONObject(json), let data = try? JSONSerialization.data(withJSONObject: json) else {
            return nil
        }
        return (try? JSONDecoder().decode(ProbabilityAnswer.self, from: data))?.value
    }
}
