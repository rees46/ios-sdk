import Foundation

class ProfileDataImpl: ProfileDataProtocol {
    
    private var sdk: PersonalizationSDK?
    private var sessionQueue: SessionQueue
    private let configProvider: SDKConfigProvider
    
    typealias RequestParams = [String: Any]
    
    init(sdk: PersonalizationSDK, configProvider: SDKConfigProvider) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
        self.configProvider = configProvider
    }
    
    private func handlePostRequest(
        path: String,
        params: RequestParams,
        timeout: TimeInterval? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard let sdk = sdk.checkInitialization(completion: completion) else { return }
        
        sdk.sessionQueue.addOperation {
            sdk.postRequest(path: path, params: params, timeout: timeout) { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func getConfigParams() -> RequestParams {
        return [
            SdkConstants.shopId: configProvider.getConfigShopId,
            SdkConstants.did: configProvider.getConfigDeviceId,
            SdkConstants.seance: configProvider.getConfigUserSeance,
            SdkConstants.sid: configProvider.getConfigUserSeance
        ]
    }
    
    private func setProfileParams(from profileData: ProfileData) -> RequestParams {
        var params: RequestParams = [:]
        
        addIfNotNil(params: &params, key: ProfileDataConstants.email, value: profileData.userEmail)
        addIfNotNil(params: &params, key: ProfileDataConstants.firstName, value: profileData.firstName)
        addIfNotNil(params: &params, key: ProfileDataConstants.lastName, value: profileData.lastName)
        addIfNotNil(params: &params, key: ProfileDataConstants.phone, value: profileData.userPhone)
        addIfNotNil(params: &params, key: ProfileDataConstants.location, value: profileData.location)
        addIfNotNil(params: &params, key: ProfileDataConstants.loyaltyCardLocation, value: profileData.loyaltyCardLocation)
        addIfNotNil(params: &params, key: ProfileDataConstants.loyaltyId, value: profileData.userLoyaltyId)
        addIfNotNil(params: &params, key: ProfileDataConstants.loyaltyStatus, value: profileData.loyaltyStatus)
        addIfNotNil(params: &params, key: ProfileDataConstants.advertisingId, value: profileData.advertisingId)
        addIfNotNil(params: &params, key: ProfileDataConstants.fbId, value: profileData.fbID)
        addIfNotNil(params: &params, key: ProfileDataConstants.vkId, value: profileData.vkID)
        addIfNotNil(params: &params, key: ProfileDataConstants.telegramId, value: profileData.telegramId)
        // The shop's id of the customer goes as both `id` and `external_id`: the server merges customers
        // by `id` and sets the profile's attribute from `external_id` (`sdk/contract/profile.md`).
        addIfNotNil(params: &params, key: ProfileDataConstants.id, value: profileData.userId)
        addIfNotNil(params: &params, key: ProfileDataConstants.externalId, value: profileData.userId)
        
        return params
    }
    
    private func setGenderParam(from profileData: ProfileData) -> RequestParams {
        guard let gender = profileData.gender else { return [:] }
        return [ProfileDataConstants.gender: (gender == .male) ? ProfileDataConstants.maleGender : ProfileDataConstants.femaleGender]
    }
    
    private func setBirthdayParam(from profileData: ProfileData) -> RequestParams {
        guard let birthday = profileData.birthday else { return [:] }
        
        return [ProfileDataConstants.birthday: Self.dayFormatter().string(from: birthday)]
    }
    
    private func setLoyaltyParams(from profileData: ProfileData) -> RequestParams {
        var params: RequestParams = [:]
        
        addIfNotNil(params: &params, key: ProfileDataConstants.loyaltyBonuses, value: profileData.loyaltyBonuses)
        addIfNotNil(params: &params, key: ProfileDataConstants.loyaltyToNextLevel, value: profileData.loyaltyBonusesToNextLevel)
        
        return params
    }
    
    private func processProfileParams(_ paramsTemp: RequestParams) -> RequestParams {
        var params: RequestParams = RequestParams()
        
        for (key, value) in paramsTemp {
            if let date = value as? Date {
                params[key] = Self.dayFormatter().string(from: date)
            } else if let array = value as? [Any] {
                params[key] = array
            } else if let jsonObject = value as? RequestParams {
                params[key] = jsonObject
            } else {
                params[key] = value
            }
        }
        
        return params
    }
    
    /// A day as `yyyy-MM-dd` of the Gregorian calendar, in the device's time zone: the calendar year
    /// (`YYYY` would be the year of the week, the next one in the last days of December), and Western
    /// digits whatever the device's locale and calendar.
    static func dayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = ProfileDataConstants.calendarYearDateFormat
        return formatter
    }

    private func setPurchaseParams(from profileData: ProfileData) -> RequestParams {
        guard let boughtSomething = profileData.boughtSomething else { return [:] }
        return [ProfileDataConstants.boughtSomething: boughtSomething ? "1" : "0"]
    }
    
    private func setCustomProperties(from profileData: ProfileData) -> RequestParams {
        return profileData.customProperties as? RequestParams ?? [:]
    }
    
    private func createParams(from profileData: ProfileData) -> RequestParams {
        var params: RequestParams = getConfigParams()
        
        params.merge(setProfileParams(from: profileData)) { (_, new) in new }
        params.merge(setGenderParam(from: profileData)) { (_, new) in new }
        params.merge(setBirthdayParam(from: profileData)) { (_, new) in new }
        params.merge(setLoyaltyParams(from: profileData)) { (_, new) in new }
        params.merge(setPurchaseParams(from: profileData)) { (_, new) in new }
        params.merge(setCustomProperties(from: profileData)) { (_, new) in new }
        
        addIfNotNil(params: &params, key: ProfileDataConstants.age, value: profileData.age)
        
        return params
    }
    
    func setProfileData(
        profileData: ProfileData,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard let sdk = sdk.checkInitialization(completion: completion) else { return }
        
        sessionQueue.addOperation {
            var paramsTemp = self.createParams(from: profileData)
            
            if let customProperties = profileData.customProperties {
                paramsTemp.merge(customProperties as RequestParams) { (_, new) in new }
            }
            
            let params = self.processProfileParams(paramsTemp)
            
            self.handlePostRequest(path: ProfileDataConstants.path, params: params, timeout: nil, completion: completion)
        }
    }
    
    private func addIfNotNil<T>(params: inout RequestParams, key: String, value: T?) {
        if let value = value {
            params[key] = value
        }
    }
}
