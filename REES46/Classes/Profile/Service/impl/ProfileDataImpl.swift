import Foundation

class ProfileDataImpl : ProfileDataProtocol{
    
    private struct Constants{
        static let path = "profile/set"
        static let shopId = "shop_id"
        static let did = "did"
        static let seance = "seance"
        static let sid = "sid"
        static let segment = "segment"
        
        static let email = "email"
        static let firstName = "first_name"
        static let lastName = "last_name"
        static let phone = "phone"
        static let location = "location"
        static let fbId = "fb_id"
        static let vkId = "vk_id"
        static let telegramId = "telegram_id"
        static let id = "id"
        static let gender = "gender"
        static let maleGender = "m"
        static let femaleGender = "f"
        
        static let loyaltyId = "loyalty_id"
        static let loyaltyStatuse = "loyalty_status"
        static let loyaltyBonuses = "loyalty_bonuses"
        static let loyaltyToNextLevel = "loyalty_bonuses_to_next_level"
        static let age = "age"
        static let loyaltyCardLocation = "loyalty_card_location"
        static let birthday = "birthday"
        static let boughtSomething = "bought_something"
        
        static let calendarYearDateFormat = "yyyy-MM-dd"
        static let weekYearDateFormat = "YYYY-MM-dd"
    }
    
    private var sdk: PersonalizationSDK?
    private var sessionQueue: SessionQueue
    typealias RequesParams = [String: Any]
    
    init(sdk: PersonalizationSDK) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
    }
    
    private func configureSession(timeOut: Double? = 1) {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = timeOut ?? 1
        sessionConfig.waitsForConnectivity = true
        sessionConfig.shouldUseExtendedBackgroundIdleMode = true
        sdk?.configureURLSession(configuration: sessionConfig)
    }
    
    private func handlePostRequest(
        path: String,
        params: RequesParams,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard let sdk = checkSdkInitialization(completion: completion) else { return }
        
        sdk.sessionQueue.addOperation {
            sdk.postRequest(path: path, params: params) { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func checkSdkInitialization(completion: @escaping (Result<Void, SDKError>) -> Void) -> PersonalizationSDK? {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "SDK is not initialized")))
            return nil
        }
        return sdk
    }
    
    private func createParams(
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
        userId: String?
    ) -> RequesParams {
        
        var paramsTemp: RequesParams = [
            Constants.shopId: sdk?.shopId ?? "",
            Constants.did: sdk?.deviceId ?? "",
            Constants.seance: sdk?.userSeance ?? "",
            Constants.sid: sdk?.userSeance ?? "",
        ]
        
        if let userEmail = userEmail {paramsTemp[Constants.email] = String(userEmail)}
        if let firstName = firstName {paramsTemp[Constants.firstName] = String(firstName)}
        if let lastName = lastName {paramsTemp[Constants.lastName] = String(lastName)}
        if let userPhone = userPhone {paramsTemp[Constants.phone] = String(userPhone)}
        if let location = location {paramsTemp[Constants.location] = String(location)}
        if let loyaltyCardLocation = loyaltyCardLocation {paramsTemp[Constants.loyaltyCardLocation] = String(loyaltyCardLocation)}
        if let userLoyaltyId = userLoyaltyId {paramsTemp[Constants.loyaltyId] = String(userLoyaltyId)}
        if let loyaltyStatus = loyaltyStatus {paramsTemp[Constants.loyaltyStatuse] = String(loyaltyStatus)}
        if let fbID = fbID {paramsTemp[Constants.fbId] = String(fbID)}
        if let vkID = vkID {paramsTemp[Constants.vkId] = String(vkID)}
        if let telegramId = telegramId {paramsTemp[Constants.telegramId] = String(telegramId)}
        if let userId = userId {paramsTemp[Constants.vkId] = String(userId)}
        if gender == .male {paramsTemp[Constants.gender] = Constants.maleGender}
        if gender == .female {paramsTemp[Constants.gender] = Constants.femaleGender}
        
        if let birthday = birthday {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = Constants.calendarYearDateFormat
            let birthdayString = dateFormatter.string(from: birthday)
            paramsTemp[Constants.birthday] = birthdayString
        }
        
        if let loyaltyBonuses = loyaltyBonuses {paramsTemp[Constants.loyaltyBonuses] = String(loyaltyBonuses)}
        if let loyaltyBonusesToNextLevel = loyaltyBonusesToNextLevel {paramsTemp[Constants.loyaltyToNextLevel] = String(loyaltyBonusesToNextLevel)}
        if let boughtSomething = boughtSomething {paramsTemp[Constants.boughtSomething] = boughtSomething == true ? "1" : "0"}
        if let age = age {paramsTemp[Constants.age] = String(age)}
        return paramsTemp
    }
    
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
    ) {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "setProfileData: SDK is not initialized")))
            return
        }
        
        sessionQueue.addOperation {
            var paramsTemp = self.createParams(
                userEmail: userEmail,
                userPhone: userPhone,
                userLoyaltyId: userLoyaltyId,
                birthday: birthday,
                age: age,
                firstName: firstName,
                lastName: lastName,
                location: location,
                gender: gender,
                fbID: fbID,
                vkID: vkID,
                telegramId: telegramId,
                loyaltyCardLocation: loyaltyCardLocation,
                loyaltyStatus: loyaltyStatus,
                loyaltyBonuses: loyaltyBonuses,
                loyaltyBonusesToNextLevel: loyaltyBonusesToNextLevel,
                boughtSomething: boughtSomething,
                userId: userId
            )
            
            if let customProperties = customProperties {
                paramsTemp.merge(customProperties as RequesParams) { (_, new) in new }
            }
            
            var params: RequesParams = RequesParams()
            for item in paramsTemp {
                if let date = item.value as? Date {
                    let formatter = DateFormatter()
                    formatter.dateFormat = Constants.weekYearDateFormat
                    params[item.key] = formatter.string(from: date)
                } else if let array = item.value as? [Any] {
                    params[item.key] = array
                } else if let jsonObject = item.value as? RequesParams {
                    params[item.key] = jsonObject
                } else {
                    params[item.key] = item.value
                }
            }
            
            self.configureSession()
            self.handlePostRequest(path: Constants.path, params: params, completion: completion)
        }
    }
}
