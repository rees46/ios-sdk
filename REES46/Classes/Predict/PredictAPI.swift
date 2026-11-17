//
//  PredictAPI.swift
//  REES46
//
//  The `predict` namespace of the contract (`sdk/contract/predict.md`).
//

import Foundation

/**
 Forecasts of the customer's behaviour. One for now: how likely the customer of this device is to buy,
 from the products they viewed, their cart and favorites of the last days.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.
 */
@_spi(Bridge)
public protocol PredictAPI {

    /**
     The probability that the customer of this device buys (`GET api/v3/cdp/users/probability-to-purchase`
     on `Rees46Config.appDomain`). The customer is the device id: the method takes no contacts, and it
     waits for the instance to have one. A customer the server does not know, or one without events, is a
     success with probability 0.

     `completion` is called once, on the main thread, with the forecast or the error: `notInitialized`
     on the old core or after `release()`, `shopBlocked`, `network`, `timeout`, `http(code:serverCode:)`
     — `400` without a device id, `402` for a shop that does not pay or has no `cdp` service, `403` for an
     inactive or restricted one, `404` for an unknown one —, `decoding` for an answer without a numeric
     `probability`, `cancelled` for a call `release()` ended. Nothing is repeated: the app decides.

     The released SDKs ask `predict/probability-to-purchase` on the API host, which answers `503`: the
     service is no longer deployed there (question 42 of `sdk/questions.md`).
     */
    func getProbabilityToPurchase(completion: @escaping (Result<PurchaseProbability, Rees46.SdkError>) -> Void)

    /// `getProbabilityToPurchase(completion:)` for `async` code: throws the `Rees46.SdkError`; cancelling
    /// the task ends the call as `cancelled`.
    func getProbabilityToPurchase() async throws -> PurchaseProbability
}

/// How likely the customer is to buy.
@_spi(Bridge)
public struct PurchaseProbability {
    /// From 0 to 1, to two decimal places.
    public let probability: Double
    /// The customer the server found by the device id; `nil` when it found none.
    public let clientId: String?
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// Forecasts of the customer's behaviour (`PredictAPI`): on the new core only.
    public var predict: PredictAPI {
        PredictAPIImpl(requests: NamespaceRequests(self))
    }
}
