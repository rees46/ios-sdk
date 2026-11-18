//
//  StoriesAPI.swift
//  REES46
//
//  The `stories` namespace of the contract (`sdk/contract/stories.md`).
//

import Foundation

/**
 The data of a stories block, for an app or a bridge that draws the stories itself. The views and the
 clicks of the slides are events of `tracking` (`storyView`, `storyClick`).

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.
 */
@_spi(Bridge)
public protocol StoriesAPI {

    /**
     The block `code` of the shop's account (`GET stories/{code}`): its stories, their slides and the
     elements of the slides. A block without stories, or one on pause, is a `StoriesBlock` with no
     stories, not an error. The request goes once the device is known to the server.

     `completion` is called once, on the main thread, with the block or the error: `invalidArgument`
     for an empty `code`, nothing sent; `notInitialized` on the old core or after `release()`,
     `shopBlocked`, `network`, `timeout`, `http(code:serverCode:)` — `404` for an unknown block, `402`
     for a shop without the stories service, `400` for a device the server does not know —, `decoding`
     for an answer that is not a JSON object, `cancelled` for a call `release()` ended. Nothing is
     repeated: the app decides.
     */
    func get(code: String, completion: @escaping (Result<StoriesBlock, Rees46.SdkError>) -> Void)

    /// `get(code:completion:)` for `async` code: throws the `Rees46.SdkError`; cancelling the task ends
    /// the call as `cancelled`.
    func get(code: String) async throws -> StoriesBlock
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The data of stories blocks (`StoriesAPI`): on the new core only.
    public var stories: StoriesAPI {
        StoriesAPIImpl(requests: NamespaceRequests(self))
    }
}
