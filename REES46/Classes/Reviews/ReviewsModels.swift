//
//  ReviewsModels.swift
//  REES46
//
//  The models of `reviews` (`sdk/contract/reviews.md`, "Модели"): flat, so a bridge hands them over as
//  they are. They are read from the answers by `ReviewsAnswers`; none is `Decodable` itself.
//

import Foundation

/// A score the server kept (`createNps`, `createCsat`, `createCes`).
@_spi(Bridge)
public struct PollReview: Equatable {
    /// The id of the review saved, or of the one updated: a score sent again the same day for the same
    /// channel, category or campaign, order and label replaces the earlier one. 64-bit, as the server's
    /// ids of reviews.
    public let id: Int

    public init(id: Int) {
        self.id = id
    }
}

/// An NPS category of the shop's account: what is scored, with the question to ask and the thanks to
/// show for each group of scores — 0–6 detractor, 7–8 passive, 9–10 promoter.
@_spi(Bridge)
public struct NpsCategory: Equatable {
    public let code: String
    public let name: String
    public let detractorQuestion: String?
    public let passiveQuestion: String?
    public let promoterQuestion: String?
    public let detractorSuccess: String?
    public let passiveSuccess: String?
    public let promoterSuccess: String?
    /// The text of the button after the score is sent.
    public let buttonLabel: String?

    public init(
        code: String, name: String,
        detractorQuestion: String? = nil, passiveQuestion: String? = nil, promoterQuestion: String? = nil,
        detractorSuccess: String? = nil, passiveSuccess: String? = nil, promoterSuccess: String? = nil,
        buttonLabel: String? = nil
    ) {
        self.code = code
        self.name = name
        self.detractorQuestion = detractorQuestion
        self.passiveQuestion = passiveQuestion
        self.promoterQuestion = promoterQuestion
        self.detractorSuccess = detractorSuccess
        self.passiveSuccess = passiveSuccess
        self.promoterSuccess = promoterSuccess
        self.buttonLabel = buttonLabel
    }
}

/// A CSAT campaign of the shop's account, with the question and the thanks for each group of scores —
/// 1–2 dissatisfied, 3 neutral, 4–5 satisfied.
@_spi(Bridge)
public struct CsatCampaign: Equatable {
    public let code: String
    public let name: String
    public let dissatisfiedQuestion: String?
    public let neutralQuestion: String?
    public let satisfiedQuestion: String?
    public let dissatisfiedSuccess: String?
    public let neutralSuccess: String?
    public let satisfiedSuccess: String?
    /// The text of the button after the score is sent.
    public let buttonLabel: String?

    public init(
        code: String, name: String,
        dissatisfiedQuestion: String? = nil, neutralQuestion: String? = nil, satisfiedQuestion: String? = nil,
        dissatisfiedSuccess: String? = nil, neutralSuccess: String? = nil, satisfiedSuccess: String? = nil,
        buttonLabel: String? = nil
    ) {
        self.code = code
        self.name = name
        self.dissatisfiedQuestion = dissatisfiedQuestion
        self.neutralQuestion = neutralQuestion
        self.satisfiedQuestion = satisfiedQuestion
        self.dissatisfiedSuccess = dissatisfiedSuccess
        self.neutralSuccess = neutralSuccess
        self.satisfiedSuccess = satisfiedSuccess
        self.buttonLabel = buttonLabel
    }
}

/// A CES campaign of the shop's account, with the question and the thanks for each group of scores —
/// 1–3 difficult, 4–5 neutral, 6–7 easy.
@_spi(Bridge)
public struct CesCampaign: Equatable {
    public let code: String
    public let name: String
    public let difficultQuestion: String?
    public let neutralQuestion: String?
    public let easyQuestion: String?
    public let difficultSuccess: String?
    public let neutralSuccess: String?
    public let easySuccess: String?
    /// The text of the button after the score is sent.
    public let buttonLabel: String?

    public init(
        code: String, name: String,
        difficultQuestion: String? = nil, neutralQuestion: String? = nil, easyQuestion: String? = nil,
        difficultSuccess: String? = nil, neutralSuccess: String? = nil, easySuccess: String? = nil,
        buttonLabel: String? = nil
    ) {
        self.code = code
        self.name = name
        self.difficultQuestion = difficultQuestion
        self.neutralQuestion = neutralQuestion
        self.easyQuestion = easyQuestion
        self.difficultSuccess = difficultSuccess
        self.neutralSuccess = neutralSuccess
        self.easySuccess = easySuccess
        self.buttonLabel = buttonLabel
    }
}

/// A channel of the polls, one for NPS, CSAT and CES.
@_spi(Bridge)
public struct PollChannel: Equatable {
    public let code: String
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

/// The published reviews of a product and its rating (`getProductReviews`).
@_spi(Bridge)
public struct ProductReviewsResponse: Equatable {
    /// Over every published review, whatever page the list is.
    public let summary: ProductRatingSummary
    /// The page asked for, newest first.
    public let reviews: [ProductReview]

    public init(summary: ProductRatingSummary, reviews: [ProductReview]) {
        self.summary = summary
        self.reviews = reviews
    }
}

/// The rating of a product over its published reviews.
@_spi(Bridge)
public struct ProductRatingSummary: Equatable {
    /// How many published reviews the product has.
    public let count: Int
    /// The mean score, rounded to 0.1 by the server; `nil` without reviews.
    public let averageRating: Double?
    /// How many reviews gave each score from 1 to 5.
    public let ratings: [Int: Int]

    public init(count: Int, averageRating: Double? = nil, ratings: [Int: Int] = [:]) {
        self.count = count
        self.averageRating = averageRating
        self.ratings = ratings
    }
}

/// A published review of a product; `id` is 64-bit, as the server's ids of reviews.
@_spi(Bridge)
public struct ProductReview: Equatable {
    public let id: Int
    /// From 1 to 5.
    public let rating: Int
    /// `nil` when the customer left a score only.
    public let comment: String?
    /// The author's name in the CDP.
    public let author: String?
    /// The date and time, ISO 8601, as the API gives it.
    public let createdAt: String

    public init(id: Int, rating: Int, comment: String? = nil, author: String? = nil, createdAt: String) {
        self.id = id
        self.rating = rating
        self.comment = comment
        self.author = author
        self.createdAt = createdAt
    }
}

/// A review the customer of this device left in an order (`getClientReviews`); `id` is 64-bit.
@_spi(Bridge)
public struct ClientReview: Equatable {
    public let id: Int
    /// The product reviewed.
    public let itemId: String
    public let orderId: String
    /// From 1 to 5.
    public let rating: Int
    public let comment: String?
    /// Where its moderation is; `nil` for a state this version of the SDK does not know.
    public let state: ReviewState?
    /// The date and time, ISO 8601, as the API gives it.
    public let createdAt: String

    public init(
        id: Int, itemId: String, orderId: String, rating: Int,
        comment: String? = nil, state: ReviewState? = nil, createdAt: String
    ) {
        self.id = id
        self.itemId = itemId
        self.orderId = orderId
        self.rating = rating
        self.comment = comment
        self.state = state
        self.createdAt = createdAt
    }
}

/// The moderation of a review. A state the server adds later is read as `nil`, never as `decoding`.
@_spi(Bridge)
public enum ReviewState: String, Equatable {
    case moderation
    case published
    case rejected
}
