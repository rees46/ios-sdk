//
//  ReviewsAnswers.swift
//  REES46
//
//  The answers of `reviews` as the API gives them (`sdk/contract/reviews.md`, "Модели"), read leniently
//  (`LenientDecoding`) into the namespace's models. A field the model can do without is empty when it is
//  missing or does not fit; an element of a list without a field the model needs is left out; an answer
//  without the object or the list the method reads is not the method's answer (`decoding`).
//

import Foundation

/// `{"payload": {"review": {"id": …}}}` of a score: the id of the review kept.
struct PollReviewAnswer: Decodable {

    let review: PollReview

    init(from decoder: Decoder) throws {
        let review = try decoder.payload().object("review")
        self.review = PollReview(id: try review.requiredInt("id"))
    }
}

/// `{"payload": {"categories": [...]}}`.
struct NpsCategoriesAnswer: Decodable {

    let items: [NpsCategory]

    init(from decoder: Decoder) throws {
        items = try decoder.payload().list(Line.self, "categories").map(\.value)
    }

    private struct Line: Decodable {
        let value: NpsCategory

        init(from decoder: Decoder) throws {
            let line = try decoder.container(keyedBy: AnswerKey.self)
            value = NpsCategory(
                code: try line.requiredString("code"),
                name: try line.requiredString("name"),
                detractorQuestion: line.lenientString("detractor_question"),
                passiveQuestion: line.lenientString("passive_question"),
                promoterQuestion: line.lenientString("promoter_question"),
                detractorSuccess: line.lenientString("detractor_success"),
                passiveSuccess: line.lenientString("passive_success"),
                promoterSuccess: line.lenientString("promoter_success"),
                buttonLabel: line.lenientString("button_label")
            )
        }
    }
}

/// `{"payload": {"channels": [...]}}`.
struct PollChannelsAnswer: Decodable {

    let items: [PollChannel]

    init(from decoder: Decoder) throws {
        items = try decoder.payload().list(Line.self, "channels").map(\.value)
    }

    private struct Line: Decodable {
        let value: PollChannel

        init(from decoder: Decoder) throws {
            let line = try decoder.container(keyedBy: AnswerKey.self)
            value = PollChannel(code: try line.requiredString("code"), name: try line.requiredString("name"))
        }
    }
}

/// `{"payload": {"campaigns": [...]}}` of CSAT.
struct CsatCampaignsAnswer: Decodable {

    let items: [CsatCampaign]

    init(from decoder: Decoder) throws {
        items = try decoder.payload().list(Line.self, "campaigns").map(\.value)
    }

    private struct Line: Decodable {
        let value: CsatCampaign

        init(from decoder: Decoder) throws {
            let line = try decoder.container(keyedBy: AnswerKey.self)
            value = CsatCampaign(
                code: try line.requiredString("code"),
                name: try line.requiredString("name"),
                dissatisfiedQuestion: line.lenientString("dissatisfied_question"),
                neutralQuestion: line.lenientString("neutral_question"),
                satisfiedQuestion: line.lenientString("satisfied_question"),
                dissatisfiedSuccess: line.lenientString("dissatisfied_success"),
                neutralSuccess: line.lenientString("neutral_success"),
                satisfiedSuccess: line.lenientString("satisfied_success"),
                buttonLabel: line.lenientString("button_label")
            )
        }
    }
}

/// `{"payload": {"campaigns": [...]}}` of CES.
struct CesCampaignsAnswer: Decodable {

    let items: [CesCampaign]

    init(from decoder: Decoder) throws {
        items = try decoder.payload().list(Line.self, "campaigns").map(\.value)
    }

    private struct Line: Decodable {
        let value: CesCampaign

        init(from decoder: Decoder) throws {
            let line = try decoder.container(keyedBy: AnswerKey.self)
            value = CesCampaign(
                code: try line.requiredString("code"),
                name: try line.requiredString("name"),
                difficultQuestion: line.lenientString("difficult_question"),
                neutralQuestion: line.lenientString("neutral_question"),
                easyQuestion: line.lenientString("easy_question"),
                difficultSuccess: line.lenientString("difficult_success"),
                neutralSuccess: line.lenientString("neutral_success"),
                easySuccess: line.lenientString("easy_success"),
                buttonLabel: line.lenientString("button_label")
            )
        }
    }
}

/// `{"payload": {"summary": {...}, "reviews": [...]}}` of `reviews/product`.
struct ProductReviewsAnswer: Decodable {

    let response: ProductReviewsResponse

    init(from decoder: Decoder) throws {
        let payload = try decoder.payload()
        let summary = try payload.object("summary")
        var ratings: [Int: Int] = [:]
        // `{"1": 0, …, "5": 3}`: a key that is not a score or a count that is not a number is left out.
        if let counts = try? summary.nestedContainer(keyedBy: AnswerKey.self, forKey: "ratings") {
            for key in counts.allKeys {
                if let score = Int(key.stringValue.trimmingCharacters(in: .whitespaces)), let count = counts.lenientInt(key) {
                    ratings[score] = count
                }
            }
        }
        response = ProductReviewsResponse(
            summary: ProductRatingSummary(
                count: try summary.requiredInt("count"),
                averageRating: summary.lenientDouble("average_rating"),
                ratings: ratings
            ),
            reviews: try payload.list(Line.self, "reviews").map(\.value)
        )
    }

    private struct Line: Decodable {
        let value: ProductReview

        init(from decoder: Decoder) throws {
            let line = try decoder.container(keyedBy: AnswerKey.self)
            value = ProductReview(
                id: try line.requiredInt("id"),
                rating: try line.requiredInt("rating"),
                comment: line.lenientString("comment"),
                author: line.lenientString("author"),
                createdAt: try line.requiredString("created_at")
            )
        }
    }
}

/// `{"payload": {"reviews": [...]}}` of `reviews/client`.
struct ClientReviewsAnswer: Decodable {

    let items: [ClientReview]

    init(from decoder: Decoder) throws {
        items = try decoder.payload().list(Line.self, "reviews").map(\.value)
    }

    private struct Line: Decodable {
        let value: ClientReview

        init(from decoder: Decoder) throws {
            let line = try decoder.container(keyedBy: AnswerKey.self)
            value = ClientReview(
                id: try line.requiredInt("id"),
                itemId: try line.requiredString("product"),
                orderId: try line.requiredString("order"),
                rating: try line.requiredInt("rating"),
                comment: line.lenientString("comment"),
                state: line.lenientEnum(ReviewState.self, "state"),
                createdAt: try line.requiredString("created_at")
            )
        }
    }
}

// MARK: - Reading

private extension Decoder {

    /// The `payload` object of the answer.
    func payload() throws -> KeyedDecodingContainer<AnswerKey> {
        try container(keyedBy: AnswerKey.self).object("payload")
    }
}

private extension KeyedDecodingContainer where Key == AnswerKey {

    /// The object at `key`; missing, `null` or not an object, the answer is not the method's.
    func object(_ key: AnswerKey) throws -> KeyedDecodingContainer<AnswerKey> {
        guard let object = try? nestedContainer(keyedBy: AnswerKey.self, forKey: key) else {
            throw missing(key, "an object")
        }
        return object
    }

    /// The list at `key` without the elements that do not read; missing, `null` or not a list, the
    /// answer is not the method's.
    func list<Element: Decodable>(_ type: Element.Type, _ key: AnswerKey) throws -> [Element] {
        guard let list = lenientList(type, key) else {
            throw missing(key, "a list")
        }
        return list
    }

    /// A string the model needs: missing, empty or not a scalar, the element does not read.
    func requiredString(_ key: AnswerKey) throws -> String {
        guard let value = lenientString(key) else { throw missing(key, "a string") }
        return value
    }

    /// An integer the model needs: missing or not one, the element does not read.
    func requiredInt(_ key: AnswerKey) throws -> Int {
        guard let value = lenientInt(key) else { throw missing(key, "an integer") }
        return value
    }

    private func missing(_ key: AnswerKey, _ what: String) -> DecodingError {
        var path = codingPath
        path.append(key)
        return DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: path,
            debugDescription: "\(key.stringValue) is not \(what)"
        ))
    }
}
