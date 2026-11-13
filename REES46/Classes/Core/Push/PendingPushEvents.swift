//
//  PendingPushEvents.swift
//  REES46
//
//  The push events of a shop that is registered and not created, on the new core (`sdk/core/push.md`,
//  `sdk/core/queue.md`): through the shop's queue on disk, without an instance.
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

/// The push events of a shop that `Rees46.register` registered and nothing created yet — the app was
/// launched by the push, say. The shop is not created for them: each event is written into the shop's
/// queue folder, `personalization_sdk/<partition>/queue/`, and sent at once under a background task,
/// with the device id the shop has stored and without `/init`. One that cannot go now — no network at a
/// cold start, a server error — stays there, and the shop's instance sends it when it is made, in this
/// launch or the next.
enum PendingPushEvents {

    /// The name of the background task that sends a pending shop's push event.
    static let backgroundTask = "com.rees46.sdk.pending_push"

    /// The seams: the network, the app's lifecycle and the clock. The tests set their own.
    static var connectivity: () -> ConnectivityMonitor = defaultConnectivity
    static var lifecycle: () -> AppLifecycle = defaultLifecycle
    static var clock: () -> Clock = defaultClock

    private static let defaultConnectivity: () -> ConnectivityMonitor = { SystemConnectivityMonitor.shared }
    private static let defaultLifecycle: () -> AppLifecycle = { SystemAppLifecycle.shared }
    private static let defaultClock: () -> Clock = { SystemClock() }

    /// The events are written here, one at a time and off the caller's thread.
    private static let work = DispatchQueue(label: "com.rees46.sdk.pending_push", qos: .utility)

    /// Takes the event of `push` for the shop's queue. `accepted` hears, off the caller's thread, whether
    /// it was: written to disk, or — the disk refusing it — sent by the one request it then goes as. A
    /// click stores the push as the source of the shop's `/push` events for 48 hours.
    static func take(_ push: PendingPush, event: Rees46.PushEvent, storage: ShopStorage, logger: SdkLogger, accepted: @escaping (Bool) -> Void) {
        let connectivity = self.connectivity()
        let lifecycle = self.lifecycle()
        let now = clock().now()
        work.async {
            if event == .clicked, let source = TrackingSourceType(rawValue: push.type) {
                TrackingSourceStoreImpl(store: storage.partition).store(type: source.rawValue, code: push.code)
            }
            let body: [String: Any] = ["code": push.code, "type": push.type]
            let client = NetworkClient(baseURL: "https://\(push.config.apiDomain)/", connectivity: connectivity, logger: logger) {
                CommonFields(
                    shopId: push.shopId,
                    deviceId: push.deviceId,
                    sessionId: "",
                    stream: push.config.stream,
                    segment: DeviceStore.shared.abGroup ?? ""
                )
            }
            let request = NetworkClient.Request(method: .post, path: event.path, body: body)
            let task = lifecycle.beginBackgroundTask(backgroundTask) {}
            EventQueue.sendDetached(
                path: event.path,
                body: body,
                createdAt: now,
                storage: storage,
                logger: logger,
                send: { await client.send(request) },
                written: { written in
                    if written {
                        accepted(true)
                    }
                },
                completion: { stored, response in
                    if !stored {
                        // Not on disk: the one request was all it had.
                        switch response.result {
                        case .success, .failure(.decoding):
                            accepted(true)
                        case .failure:
                            accepted(false)
                        }
                    }
                    task.cancel()
                }
            )
        }
    }

    /// Test-only: the system's seams again.
    static func reset() {
        connectivity = defaultConnectivity
        lifecycle = defaultLifecycle
        clock = defaultClock
    }
}
