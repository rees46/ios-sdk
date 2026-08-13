//
//  LocalStateRepository.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Per-shop UI state that the stories block persists: which slides a user has viewed, which slide media
 has been downloaded, and which products are in the cart / favourites.

 Multi-instance (R2): this state used to live in `UserDefaults.standard` under composed keys
 (`viewed.slide.<storyId>`, `cached.slide.<slideId>`, `cart.product.<id>`, `favorites.product.<id>`).
 Slide and product ids are not unique across shops (they are small integers), so a shared store let
 one shop see another's viewed/cart/favourites/downloaded state. This port scopes it to the shop's
 partition. The keys are composed inside the implementation, so call sites deal in ids only.

 Note: the `cached.slide.<id>` **notification names** used for in-process signalling are a separate
 concern and are intentionally left un-partitioned — only the persisted state moves here.
 */
protocol LocalStateRepository: AnyObject {

    func viewedSlides(storyId: String) -> [String]
    func setViewedSlides(_ slides: [String], storyId: String)

    func downloadedMedia(slideId: String) -> [String]
    func setDownloadedMedia(_ media: [String], slideId: String)

    func cartProducts(productId: String) -> [String]
    func setCartProducts(_ products: [String], productId: String)

    func favoriteProducts(productId: String) -> [String]
    func setFavoriteProducts(_ products: [String], productId: String)

    func clearViewedSlides()
    func clearDownloadedMedia()
    func clearCartProducts()
    func clearFavoriteProducts()
}
