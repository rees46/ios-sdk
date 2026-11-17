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

    /// `GET predict/probability-to-purchase` with nothing but the common fields: the server finds the
    /// customer by the device id, which wins over any contact (question 44 of `sdk/questions.md`), so
    /// none is sent. The general read timeout, not the 15 seconds of the old method.
    static var probabilityRequest: ApiRequest<PurchaseProbability> {
        .get("predict/probability-to-purchase", answer: ProbabilityAnswer.self) { $0.value }
    }
}

/// `{"probability": 0.42, "client_id": 12345}`: a `client_id` that is `null` or missing is no customer,
/// a success. Without a numeric `probability` it is not a forecast (`decoding`).
struct ProbabilityAnswer: Decodable {

    let value: PurchaseProbability

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnswerKey.self)
        guard let probability = root.lenientDouble("probability") else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "no numeric probability"
            ))
        }
        value = PurchaseProbability(probability: probability, clientId: root.lenientString("client_id"))
    }
}
