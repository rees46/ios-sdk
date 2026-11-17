//
//  ApiArguments.swift
//  REES46
//
//  The text arguments of the namespaces' methods (`sdk.<namespace>.<method>`) as the contract reads them
//  (`sdk/contract/README.md`): a required one may not be blank, an optional blank one is not sent.
//

import Foundation

enum ApiArguments {

    /// Empty or only whitespace: a required text the contract refuses as `invalidArgument`.
    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// An optional text as it is sent: `nil`, empty and blank are none.
    static func given(_ text: String?) -> String? {
        text.flatMap { isBlank($0) ? nil : $0 }
    }
}
