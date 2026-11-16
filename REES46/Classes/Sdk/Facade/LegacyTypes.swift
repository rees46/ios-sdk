import Foundation

/**
 The SDK's first error type, under a name of its own.

 `Rees46` nests a `SdkError` of its own, so inside it a plain `SdkError` is the nested one. The
 module's name cannot point at this one either: a synchronized copy of the SDK renames the module
 and `Rees46` to the same word, where the module-qualified name would mean the nested type. This
 name stays the same in every copy.
 */
public typealias LegacySdkError = SdkError

/// The push events of earlier versions, under a name of its own for the same reason as `LegacySdkError`.
public typealias LegacyPushEvent = PushEvent
