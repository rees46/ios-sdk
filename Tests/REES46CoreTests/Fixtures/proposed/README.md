# Proposed fixtures

Cases the SDK is tested by for a namespace the contract has no fixture file for yet, written in the format of the
contract's fixtures (`sdk/fixtures/README.md`) and marked with the contract version they follow. They are not the
contract's: when `sdk/fixtures` gets the namespace's file, its copy goes into `contract-<version>/` and the file here
is removed.

- `cart.json` — `cart.get` (`sdk/contract/cart.md`), the same cases the Android SDK tests by. In `expect`, `result`
  is the method's value by the contract's field names; `response.status: null` is no answer, which the tests play as a
  connection that is never made (`network`).
- `notifications.json` — the events of pushes and `setPushToken` (`sdk/contract/notifications.md`), the same cases the
  Android SDK tests by. A case with `platform` (`ios`, `android`) is of that platform only: the platforms send a push
  token with different `platform` and `push_provider`, and each refuses the other's provider. `expect.result: null` is a
  success without a value.
- `stories.json` — `stories.get` (`sdk/contract/stories.md`). In `expect.result` an element of a slide is an object with
  its `type` — `button`, `product`, `products`, `textBlock` — and its fields.
- `predict.json` — `predict.getProbabilityToPurchase` (`sdk/contract/predict.md`).
- `loyalty.json` — `loyalty.join`, `getStatus`, `getPromotions` (`sdk/contract/loyalty.md`). A query field whose value
  is a list goes as a list of Rails: `promo_codes[]=A&promo_codes[]=B`.
- `sliders.json` — `sliders.get` (`sdk/contract/sliders.md`) and the banner events of `tracking` that go with it,
  `bannerView` and `bannerClick`, until the contract's `tracking.json` has them.

In `expect.result` an object lists the fields the case checks; `null` is a field without a value.
