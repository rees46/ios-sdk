# Proposed fixtures

Cases the SDK is tested by for a namespace the contract has no fixture file for yet, written in the format of the
contract's fixtures (`sdk/fixtures/README.md`) and marked with the contract version they follow. They are not the
contract's: when `sdk/fixtures` gets the namespace's file, its copy goes into `contract-<version>/` and the file here
is removed.

- `cart.json` — `cart.get` (`sdk/contract/cart.md`), the same cases the Android SDK tests by. In `expect`, `result`
  is the method's value by the contract's field names; `response.status: null` is no answer, which the tests play as a
  connection that is never made (`network`).
- `reviews.json` — the nine methods of `reviews` (`sdk/contract/reviews.md`): the request of each call, or the
  argument it refuses, and what each answer ends with. A path under `api/v3/` goes to `appDomain`, any other to
  `apiDomain`, as the contract's table of methods says; the format has no field for the host.
