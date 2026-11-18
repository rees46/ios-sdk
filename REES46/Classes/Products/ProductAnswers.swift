//
//  ProductAnswers.swift
//  REES46
//
//  How the catalog's answers become its models, by the rules of `LenientDecoding`: a model reads itself
//  from the answer's object (`AnswerReadable`) and stays out of `Decodable`, which would hand its
//  decoding to the app as API.
//

import Foundation

/// A model the namespaces read from an object of an answer. It throws when the object is not one of
/// it — a product without an id —: an element of a list is then left out, a whole answer is `decoding`.
protocol AnswerReadable {
    init(answer: KeyedDecodingContainer<AnswerKey>) throws
}

/// `Value` read from an answer, as a `Decodable`.
struct Readable<Value: AnswerReadable>: Decodable {
    let value: Value

    init(from decoder: Decoder) throws {
        value = try Value(answer: decoder.container(keyedBy: AnswerKey.self))
    }

    /// The method's value of a whole answer: `body` is an object of `Value`, or `decoding`.
    static func read(_ body: Data) throws -> Value {
        try JSONDecoder().decode(Readable.self, from: body).value
    }

    /// The method's value of an answer that is a list of `Value` at its top, without the elements that
    /// are not one; an answer that is not a list is `decoding`.
    static func readList(_ body: Data) throws -> [Value] {
        try JSONDecoder().decode([Element].self, from: body).compactMap(\.value)
    }

    /// An element of a list at the top of an answer: `nil` when it is not a `Value`.
    private struct Element: Decodable {
        let value: Value?

        init(from decoder: Decoder) throws {
            value = try? Value(answer: decoder.container(keyedBy: AnswerKey.self))
        }
    }
}

/// One element of a list of strings: a string, or a number as its digits. Anything else, and an empty
/// or blank string, is left out.
private struct AnswerString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "an empty string")
            }
            value = text
        } else if let number = try? container.decode(Int.self) {
            value = String(number)
        } else if let number = try? container.decode(Double.self), number.isFinite {
            value = CatalogQuery.number(number)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "not a string")
        }
    }
}

extension KeyedDecodingContainer {

    /// The string at `key`, or the error that makes the object not a model.
    func requiredString(_ key: Key) throws -> String {
        guard let value = lenientString(key) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "no \(key.stringValue)"))
        }
        return value
    }

    /// The string at `key` for a field a model cannot do without: an empty one is a value here, a missing
    /// one, `null` or one that is not a scalar the error that makes the object not a model.
    func requiredText(_ key: Key) throws -> String {
        if let value = lenientString(key) ?? (try? decodeIfPresent(String.self, forKey: key)) {
            return value
        }
        throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "no \(key.stringValue)"))
    }

    /// The number at `key` for a field a model cannot do without.
    func requiredDouble(_ key: Key) throws -> Double {
        guard let value = lenientDouble(key) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "no \(key.stringValue)"))
        }
        return value
    }

    /// The integer at `key` for a field a model cannot do without.
    func requiredInt(_ key: Key) throws -> Int {
        guard let value = lenientInt(key) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "no \(key.stringValue)"))
        }
        return value
    }

    /// The model at `key`; `nil` when it is missing or not one.
    func model<Value: AnswerReadable>(_ type: Value.Type, _ key: Key) -> Value? {
        lenient(Readable<Value>.self, key)?.value
    }

    /// The models of the list at `key`, without the elements that are not one; `nil` when it is missing
    /// or not a list.
    func models<Value: AnswerReadable>(_ type: Value.Type, _ key: Key) -> [Value]? {
        lenientList(Readable<Value>.self, key)?.map(\.value)
    }

    /// The models of the list at `key`, or the error that makes the answer not one of the method: the
    /// main list of an answer.
    func requiredModels<Value: AnswerReadable>(_ type: Value.Type, _ key: Key) throws -> [Value] {
        guard let list = models(type, key) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "no list \(key.stringValue)"))
        }
        return list
    }

    /// The strings of the list at `key`, numbers as their digits; `nil` when it is missing or not a list.
    func lenientStrings(_ key: Key) -> [String]? {
        lenientList(AnswerString.self, key)?.map(\.value)
    }

    /// The object at `key` as a map of names to strings, numbers as their digits; `nil` when it is
    /// missing or not an object.
    func lenientStringMap(_ key: Key) -> [String: String]? {
        lenientMap(key) { $0.lenientString($1) }
    }

    /// The object at `key` as a map of names to integers; `nil` when it is missing or not an object.
    func lenientIntMap(_ key: Key) -> [String: Int]? {
        lenientMap(key) { $0.lenientInt($1) }
    }

    /// The object at `key` as a map of names to models; `nil` when it is missing or not an object.
    func modelMap<Value: AnswerReadable>(_ type: Value.Type, _ key: Key) -> [String: Value]? {
        lenientMap(key) { $0.model(type, $1) }
    }

    /// The object at `key`, each of its values read by `value`; a value it cannot read is left out. An
    /// empty list is an empty object: the server writes an empty object so (PHP).
    private func lenientMap<Value>(
        _ key: Key,
        _ value: (KeyedDecodingContainer<AnswerKey>, AnswerKey) -> Value?
    ) -> [String: Value]? {
        guard let object = try? nestedContainer(keyedBy: AnswerKey.self, forKey: key) else {
            let list = try? nestedUnkeyedContainer(forKey: key)
            return list?.count == 0 ? [:] : nil
        }
        var map: [String: Value] = [:]
        for name in object.allKeys {
            map[name.stringValue] = value(object, name)
        }
        return map
    }
}

// MARK: - Products

extension Rees46.Product: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        try self.init(answer: answer, preferringUniqid: false)
    }

    /// `preferringUniqid`: the card's answer (`products/get`), where `uniqid` is the shop's id.
    /// `paramOrder`: the names of `params` in the answer's order, when it is an object (`productParams`).
    init(answer: KeyedDecodingContainer<AnswerKey>, preferringUniqid: Bool, paramOrder: [String] = []) throws {
        id = try (preferringUniqid ? answer.lenientString("uniqid") : nil) ?? answer.requiredString("id")
        groupId = answer.lenientString("group_id")
        name = try answer.requiredText("name")
        brand = answer.lenientString("brand")
        model = answer.lenientString("model")
        description = answer.lenientString("description")
        barcode = answer.lenientString("barcode")
        url = try answer.requiredText("url")
        deeplinkAndroid = answer.lenientString("deeplink_android")
        deeplinkIos = answer.lenientString("deeplink_ios")
        imageUrl = answer.lenientString("image_url")
        picture = answer.lenientString("picture")
        resizedImages = answer.lenientStringMap("image_url_resized")
        price = try answer.requiredDouble("price")
        priceFormatted = answer.lenientString("price_formatted")
        priceFull = answer.lenientDouble("price_full")
        priceFullFormatted = answer.lenientString("price_full_formatted")
        // No old price is 0 in the answer.
        oldPrice = answer.lenientDouble("oldprice").flatMap { $0 > 0 ? $0 : nil }
        oldPriceFormatted = answer.lenientString("oldprice_formatted")
        oldPriceFull = answer.lenientDouble("oldprice_full").flatMap { $0 > 0 ? $0 : nil }
        oldPriceFullFormatted = answer.lenientString("oldprice_full_formatted")
        currency = try answer.requiredText("currency")
        // `discount` is a flag in the card, a number elsewhere: a flag reads as no integer.
        discountPercent = answer.lenientInt("discount_percent") ?? answer.lenientInt("discount")
        discountFormatted = answer.lenientString("discount_formatted")
        salesRate = answer.lenientInt("sales_rate")
        relativeSalesRate = answer.lenientDouble("relative_sales_rate")
        rating = answer.lenientInt("rating")
        isNew = answer.lenientBool("is_new") ?? false
        stockQuantity = answer.lenientInt("stock_quantity")
        categoryIds = answer.lenientStrings("category_ids")
        categories = answer.models(Rees46.ProductCategory.self, "categories")
        params = answer.models(Rees46.ProductParam.self, "params") ?? answer.productParams("params", order: paramOrder)
        locationIds = answer.lenientStrings("location_ids")
    }
}

extension Rees46.ProductCategory: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        id = try answer.requiredString("id")
        name = answer.lenientString("name")
        url = answer.lenientString("url")
        parentId = answer.lenientString("parent_id") ?? answer.lenientString("parent")
        level = answer.lenientInt("level")
        count = answer.lenientInt("count")
        alias = answer.lenientString("alias")
    }
}

extension Rees46.ProductParam: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        key = try answer.requiredString("key")
        values = answer.lenientStrings("values") ?? []
    }
}

extension KeyedDecodingContainer where Key == AnswerKey {

    /// The parameters at `key` when they are an object, as the card's answer (`products/get`) writes them
    /// — name → `{"searchable": true, "value": [...]}` —, where the other answers have a list of
    /// `{"key", "values"}`. In the order of `order`, the answer's own, which the decoder does not keep;
    /// by name for one `order` does not have. `nil` when `key` is not an object.
    func productParams(_ key: Key, order: [String]) -> [Rees46.ProductParam]? {
        guard let object = try? nestedContainer(keyedBy: AnswerKey.self, forKey: key) else { return nil }
        var rank: [String: Int] = [:]
        for (position, name) in order.enumerated() where rank[name] == nil {
            rank[name] = position
        }
        let names = object.allKeys.map(\.stringValue).sorted {
            (rank[$0] ?? Int.max, $0) < (rank[$1] ?? Int.max, $1)
        }
        return names.map { name in
            let field = AnswerKey(name)
            let entry = try? object.nestedContainer(keyedBy: AnswerKey.self, forKey: field)
            let values = entry?.lenientStrings("value")
                ?? entry?.lenientString("value").map { [$0] }
                ?? object.lenientStrings(field)
                ?? object.lenientString(field).map { [$0] }
            return Rees46.ProductParam(key: name, values: values ?? [])
        }
    }
}

/// The order of the keys of an object in an answer, which `JSONDecoder` does not keep: the order the shop
/// gave the parameters of a product in the card's answer (`products/get`).
struct AnswerKeyOrder {

    private let bytes: [UInt8]
    private var index = 0

    /// The keys of the object at `key` of the object at the top of `data`, in the answer's order; `nil`
    /// when the answer is not an object of JSON or `key` is not an object in it.
    static func keys(ofObjectAt key: String, in data: Data) -> [String]? {
        var scanner = AnswerKeyOrder(bytes: [UInt8](data))
        guard scanner.consume("{"), !scanner.consume("}") else { return nil }
        repeat {
            guard let name = scanner.member() else { return nil }
            if name == key {
                return scanner.objectKeys()
            }
            guard scanner.skipValue() else { return nil }
        } while scanner.consume(",")
        return nil
    }

    /// The keys of the object at the index, in their order; the index after it.
    private mutating func objectKeys() -> [String]? {
        guard consume("{") else { return nil }
        var keys: [String] = []
        if consume("}") {
            return keys
        }
        repeat {
            guard let name = member(), skipValue() else { return nil }
            keys.append(name)
        } while consume(",")
        return consume("}") ? keys : nil
    }

    /// The key of a member and its colon.
    private mutating func member() -> String? {
        guard let name = string(), consume(":") else { return nil }
        return name
    }

    /// Moves past the value at the index; `false` when there is none.
    private mutating func skipValue() -> Bool {
        skipSpace()
        guard index < bytes.count else { return false }
        switch bytes[index] {
        case UInt8(ascii: "\""):
            return string() != nil
        case UInt8(ascii: "{"), UInt8(ascii: "["):
            var depth = 0
            while index < bytes.count {
                switch bytes[index] {
                case UInt8(ascii: "\""):
                    guard string() != nil else { return false }
                    continue
                case UInt8(ascii: "{"), UInt8(ascii: "["):
                    depth += 1
                case UInt8(ascii: "}"), UInt8(ascii: "]"):
                    depth -= 1
                    if depth == 0 {
                        index += 1
                        return true
                    }
                default:
                    break
                }
                index += 1
            }
            return false
        default:
            let start = index
            while index < bytes.count, !Self.ends.contains(bytes[index]) {
                index += 1
            }
            return index > start
        }
    }

    /// What ends a number, `true`, `false` or `null`.
    private static let ends = Set(",}] \t\r\n".utf8)

    /// The string at the index, its escapes read; the index after its closing quote.
    private mutating func string() -> String? {
        skipSpace()
        guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { return nil }
        let start = index
        var escaped = false
        index += 1
        while index < bytes.count {
            switch bytes[index] {
            case UInt8(ascii: "\\"):
                escaped = true
                index += 2
            case UInt8(ascii: "\""):
                index += 1
                let token = Data(bytes[start..<index])
                guard escaped else {
                    return String(decoding: token.dropFirst().dropLast(), as: UTF8.self)
                }
                return (try? JSONSerialization.jsonObject(with: token, options: .fragmentsAllowed)) as? String
            default:
                index += 1
            }
        }
        return nil
    }

    /// Moves past `character` at the index, after any white space; `false` when it is not there.
    private mutating func consume(_ character: Unicode.Scalar) -> Bool {
        skipSpace()
        guard index < bytes.count, bytes[index] == UInt8(ascii: character) else { return false }
        index += 1
        return true
    }

    private mutating func skipSpace() {
        while index < bytes.count, Self.space.contains(bytes[index]) {
            index += 1
        }
    }

    private static let space = Set(" \t\r\n".utf8)
}

extension Rees46.Location: AnswerReadable {

    /// A location without an id or a name is left out.
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        id = try answer.requiredString("id")
        name = try answer.requiredText("name")
        type = answer.lenientString("type")
    }
}

extension Rees46.Brand: AnswerReadable {

    /// A brand without a name or a count is left out.
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        name = try answer.requiredText("name")
        count = try answer.requiredInt("count")
    }
}

extension Rees46.SearchFilter: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        count = answer.lenientInt("count")
        priority = answer.lenientInt("priority")
        values = answer.lenientIntMap("values")
        let ranges = try? answer.nestedContainer(keyedBy: AnswerKey.self, forKey: "ranges")
        min = ranges?.lenientDouble("min")
        max = ranges?.lenientDouble("max")
    }
}

extension Rees46.IndustrialFilters: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        colors = answer.models(Rees46.ColorFilter.self, "colors")
        fashionSizes = answer.models(Rees46.SizeFilter.self, "fashion_sizes")
    }
}

extension Rees46.ColorFilter: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        color = try answer.requiredText("color")
        count = try answer.requiredInt("count")
    }
}

extension Rees46.SizeFilter: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        size = try answer.requiredText("size")
        count = try answer.requiredInt("count")
    }
}

extension Rees46.PriceRange: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        guard let min = answer.lenientDouble("min"), let max = answer.lenientDouble("max") else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: answer.codingPath, debugDescription: "no min or max"))
        }
        self.min = min
        self.max = max
    }
}

extension Rees46.PriceInterval: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        from = answer.lenientDouble("from") ?? 0
        to = answer.lenientDouble("to")
        count = answer.lenientInt("count")
    }
}

extension Rees46.ProductsListResponse: AnswerReadable {

    /// Without a list of products it is not a listing (`decoding`).
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        products = try answer.requiredModels(Rees46.Product.self, "products")
        productsTotal = answer.lenientInt("products_total")
        categories = answer.models(Rees46.ProductCategory.self, "categories")
        brands = answer.models(Rees46.Brand.self, "brands")
        locations = answer.models(Rees46.Location.self, "locations")
        filters = answer.modelMap(Rees46.SearchFilter.self, "filters")
        industrialFilters = answer.model(Rees46.IndustrialFilters.self, "industrial_filters")
        priceRange = answer.model(Rees46.PriceRange.self, "price_range")
        priceRanges = answer.models(Rees46.PriceInterval.self, "price_ranges")
        priceMedian = answer.lenientDouble("price_median")
    }
}

extension Rees46.CategoryResponse {

    /// The listing of the category: the same answer without what a category has not.
    init(_ list: Rees46.ProductsListResponse) {
        productsTotal = list.productsTotal
        products = list.products
        categories = list.categories
        brands = list.brands
        filters = list.filters
        priceRange = list.priceRange
        priceRanges = list.priceRanges
        priceMedian = list.priceMedian
    }
}

extension ProductCountersResponse: AnswerReadable {

    /// The released model, read leniently: a counter the answer does not have is 0, as the old
    /// `getProductCounters` reads it.
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        daily = answer.model(ProductCounter.self, "daily")
        now = answer.model(ProductCounter.self, "now")
        triggers = answer.model(ProductCounterTriggers.self, "triggers")
    }
}

extension ProductCounter: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        view = answer.lenientInt("view") ?? 0
        cart = answer.lenientInt("cart") ?? 0
        purchase = answer.lenientInt("purchase") ?? 0
    }
}

extension ProductCounterTriggers: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        backInStock = answer.lenientInt("back_in_stock") ?? 0
        priceDrop = answer.lenientInt("price_drop") ?? 0
    }
}
