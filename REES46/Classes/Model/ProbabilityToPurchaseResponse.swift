import Foundation

/// The forecast of `getProbabilityToPurchase(params:completion:)`.
public struct ProbabilityToPurchaseResponse {
    /// From 0 to 1.
    public let probability: Double
    /// The customer the server found by the device id; empty when it found none.
    public let clientId: String

    /// The old model of the forecast `predict.getProbabilityToPurchase` reads.
    init(_ forecast: PurchaseProbability) {
        probability = forecast.probability
        clientId = forecast.clientId ?? ""
    }
}
