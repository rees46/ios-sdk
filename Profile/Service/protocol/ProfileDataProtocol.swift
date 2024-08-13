import Foundation

protocol ProfileDataProtocol{
    
    func setProfileData(
        userEmail: String?,
        userPhone: String?,
        userLoyaltyId: String?,
        birthday: Date?,
        age: Int?,
        firstName: String?,
        lastName: String?,
        location: String?,
        gender: Gender?,
        fbID: String?,
        vkID: String?,
        telegramId: String?,
        loyaltyCardLocation: String?,
        loyaltyStatus: String?,
        loyaltyBonuses: Int?,
        loyaltyBonusesToNextLevel: Int?,
        boughtSomething: Bool?,
        userId: String?,
        customProperties: [String: Any?]?,
        completion: @escaping (Result<Void, SDKError>) -> Void
    )
    
}
