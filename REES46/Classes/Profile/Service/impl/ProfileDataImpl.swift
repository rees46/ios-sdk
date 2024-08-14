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
    
    private func configureSession(timeOut: Double? = 1) {
        let session = URLSession.configuredSession(timeOut: timeOut ?? 1)
        sdk?.configureURLSession(configuration: session.configuration)
    }
    
    private func handlePostRequest(
        path: String,
        params: RequestParams,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard let sdk = sdk.checkInitialization(completion: completion) else { return }
        
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
        addIfNotNil(params: &params, key: ProfileDataConstants.fbId, value: profileData.fbID)
        addIfNotNil(params: &params, key: ProfileDataConstants.vkId, value: profileData.vkID)
        addIfNotNil(params: &params, key: ProfileDataConstants.telegramId, value: profileData.telegramId)
        addIfNotNil(params: &params, key: ProfileDataConstants.id, value: profileData.userId)
        
        return params
    }
    
    private func setGenderParam(from profileData: ProfileData) -> RequestParams {
        guard let gender = profileData.gender else { return [:] }
        return [ProfileDataConstants.gender: (gender == .male) ? ProfileDataConstants.maleGender : ProfileDataConstants.femaleGender]
    }
    
    private func setBirthdayParam(from profileData: ProfileData) -> RequestParams {
        guard let birthday = profileData.birthday else { return [:] }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = ProfileDataConstants.calendarYearDateFormat
        return [ProfileDataConstants.birthday: dateFormatter.string(from: birthday)]
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
                let formatter = DateFormatter()
                formatter.dateFormat = ProfileDataConstants.weekYearDateFormat
                params[key] = formatter.string(from: date)
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
            
            self.configureSession()
            self.handlePostRequest(path: ProfileDataConstants.path, params: params, completion: completion)
        }
    }
    
    private func addIfNotNil<T>(params: inout RequestParams, key: String, value: T?) {
        if let value = value {
            params[key] = value
        }
    }
}
