# Proposed fixtures

Cases the SDK is tested by for a namespace the contract has no fixture file for yet, written in the format of the
contract's fixtures (`sdk/fixtures/README.md`) and marked with the contract version they follow. They are not the
contract's: when `sdk/fixtures` gets the namespace's file, its copy goes into `contract-<version>/` and the file here
is removed.

- `cart.json` — `cart.get` (`sdk/contract/cart.md`), the same cases the Android SDK tests by. In `expect`, `result`
  is the method's value by the contract's field names; `response.status: null` is no answer, which the tests play as a
  connection that is never made (`network`).
- `products.json`, `collections.json`, `recommendations.json`, `search.json` — the catalog (`sdk/contract/products.md`,
  `collections.md`, `recommendations.md`, `search.md`). In `call.args`, a request model is an object by the contract's
  field names, a value of a set by its name in code (`salesRate`). In `request.query`, `null` is a field that must not
  be sent. In `expect.result`, only the fields listed count, `null` is a field without a value, and `{}` is an empty
  map.
