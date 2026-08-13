//
//  LocalStateRepositoryImpl.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 `UserDefaults`-backed [LocalStateRepository] over the shop's partition suite, so viewed / downloaded
 / cart / favourites state is isolated per shop. Preserves the original key scheme (the values are
 arrays of ids), so migrated behaviour is byte-for-byte the same — only the domain changes.
 */
final class LocalStateRepositoryImpl: LocalStateRepository {

    private static let viewedSlidePrefix = "viewed.slide."
    private static let cachedSlidePrefix = "cached.slide."
    private static let cartPrefix = "cart.product."
    private static let favoritesPrefix = "favorites.product."

    private let store: UserDefaults

    init(store: UserDefaults) {
        self.store = store
    }

    func viewedSlides(storyId: String) -> [String] {
        array(Self.viewedSlidePrefix + storyId)
    }

    func setViewedSlides(_ slides: [String], storyId: String) {
        store.set(slides, forKey: Self.viewedSlidePrefix + storyId)
    }

    func downloadedMedia(slideId: String) -> [String] {
        array(Self.cachedSlidePrefix + slideId)
    }

    func setDownloadedMedia(_ media: [String], slideId: String) {
        store.set(media, forKey: Self.cachedSlidePrefix + slideId)
    }

    func cartProducts(productId: String) -> [String] {
        array(Self.cartPrefix + productId)
    }

    func setCartProducts(_ products: [String], productId: String) {
        store.set(products, forKey: Self.cartPrefix + productId)
    }

    func favoriteProducts(productId: String) -> [String] {
        array(Self.favoritesPrefix + productId)
    }

    func setFavoriteProducts(_ products: [String], productId: String) {
        store.set(products, forKey: Self.favoritesPrefix + productId)
    }

    func clearViewedSlides() { removeAll(withPrefix: Self.viewedSlidePrefix) }
    func clearDownloadedMedia() { removeAll(withPrefix: Self.cachedSlidePrefix) }
    func clearCartProducts() { removeAll(withPrefix: Self.cartPrefix) }
    func clearFavoriteProducts() { removeAll(withPrefix: Self.favoritesPrefix) }

    private func array(_ key: String) -> [String] {
        store.stringArray(forKey: key) ?? []
    }

    private func removeAll(withPrefix prefix: String) {
        for key in store.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            store.removeObject(forKey: key)
        }
    }
}
