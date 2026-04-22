# REES46 iOS SDK changelog

## Unreleased

### Features

* Strict purchase tracking: `trackPurchase(_:recommendedBy:completion:)` with `PurchaseTrackingRequest` / `PurchaseItemRequest` (camelCase API; snake_case on the wire). Validation before send; `tax_free` only when `isTaxFree` is true; optional properties omitted when unset. Demo buttons for minimal and full payloads.

### Deprecations

* `Event.orderCreated` — use `trackPurchase` with `PurchaseTrackingRequest` instead.

## Earlier releases

See release tags and commit history for versions prior to this file.
