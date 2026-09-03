# REES46 iOS SDK changelog

## Unreleased

### Features

* Purchase tracking: optional `isGiftPackage` on `PurchaseTrackingRequest` — sent as `gift_package` only when `true`, the way `tax_free` is.
* Strict purchase tracking: `trackPurchase(_:recommendedBy:completion:)` with `PurchaseTrackingRequest` / `PurchaseItemRequest` (camelCase API; snake_case on the wire). Validation before send; `tax_free` only when `isTaxFree` is true; optional properties omitted when unset. Demo buttons for minimal and full payloads.
* The stories block collapses when a load brings nothing to show — a block switched off in the dashboard, or a failed request — instead of leaving an empty row on the screen. New `StoriesView.hasStories`, `onStoriesCollapse`, `StoriesView.defaultHeight` and `StoriesWidget.onCollapse(_:)` for hosts that pin the height themselves or draw their own header around the block.

### Fixes

* Stories: the loaded list is handed to the collection view on the main queue, which closes a crash (`Index out of range`) when the placeholder row outlived a shorter or empty list.

### Deprecations

* `Event.orderCreated` — use `trackPurchase` with `PurchaseTrackingRequest` instead.

## Earlier releases

See release tags and commit history for versions prior to this file.
