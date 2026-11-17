# Proposed fixtures

Cases the SDK is tested by for a namespace the contract has no fixture file for yet, written in the format of the
contract's fixtures (`sdk/fixtures/README.md`) and marked with the contract version they follow. They are not the
contract's: when `sdk/fixtures` gets the namespace's file, its copy goes into `contract-<version>/` and the file here
is removed.

- `cart.json` — `cart.get` (`sdk/contract/cart.md`), the same cases the Android SDK tests by. In `expect`, `result`
  is the method's value by the contract's field names; `response.status: null` is no answer, which the tests play as a
  connection that is never made (`network`).
- `products.json`, `collections.json`, `recommendations.json`, `search.json` — the catalog (`sdk/contract/products.md`,
  `collections.md`, `recommendations.md`, `search.md`): the Android SDK's files as they are, so both SDKs test the same
  cases. In `call.args`, a request model is an object by the contract's field names, a value of a set by its name in
  code (`salesRate`). A `result`, and a request's own fields in `query` or `body`, are compared whole, as the Android
  SDK compares them: a field without a value counts as missing on either side.
- `profile.json`, `subscriptions.json`, `segments.json` — the client (`sdk/contract/profile.md`, `subscriptions.md`,
  `segments.md`): the Android SDK's files as they are, compared as the catalog's. A method without a value expects
  `"result": null`.
