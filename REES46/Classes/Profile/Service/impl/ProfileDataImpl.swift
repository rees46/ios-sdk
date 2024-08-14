import Foundation

class ProfileDataImpl : ProfileDataProtocol{
    
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
    
    private func checkSdkInitialization(
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) -> PersonalizationSDK? {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "SDK is not initialized")))
            return nil
        }
        return sdk
    }
    
    private func createParams(from profileData: ProfileData) -> RequesParams {
        var params: RequesParams = [
            SdkConstants.shopId: sdk?.shopId ?? "",
            SdkConstants.did: sdk?.deviceId ?? "",
            SdkConstants.seance: sdk?.userSeance ?? "",
            SdkConstants.sid: sdk?.userSeance ?? ""
        ]
        
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
        
        if let gender = profileData.gender {
            params[ProfileDataConstants.gender] = (gender == .male) ? ProfileDataConstants.maleGender : ProfileDataConstants.femaleGender
        }
        
        if let birthday = profileData.birthday {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = ProfileDataConstants.calendarYearDateFormat
            params[ProfileDataConstants.birthday] = dateFormatter.string(from: birthday)
        }
        
        addIfNotNil(params: &params, key: ProfileDataConstants.loyaltyBonuses, value: profileData.loyaltyBonuses)
        addIfNotNil(params: &params, key: ProfileDataConstants.loyaltyToNextLevel, value: profileData.loyaltyBonusesToNextLevel)
        
        if let boughtSomething = profileData.boughtSomething {
            params[ProfileDataConstants.boughtSomething] = boughtSomething ? "1" : "0"
        }
        
        addIfNotNil(params: &params, key: ProfileDataConstants.age, value: profileData.age)
        
        if let customProperties = profileData.customProperties {
            params.merge(customProperties as RequesParams) {
                (_, new) in new
            }
        }
        
        return params
    }
    
    private func addIfNotNil<T>(params: inout RequesParams, key: String, value: T?) {
        if let value = value {
            params[key] = value
        }
    }
    
    func setProfileData(
        profileData: ProfileData,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "setProfileData: SDK is not initialized")))
            return
        }
        
        sessionQueue.addOperation {
            var paramsTemp = self.createParams(from: profileData)
            
            if let customProperties = profileData.customProperties {
                paramsTemp.merge(customProperties as RequesParams) { (_, new) in new }
            }
            
            var params: RequesParams = RequesParams()
            for item in paramsTemp {
                if let date = item.value as? Date {
                    let formatter = DateFormatter()
                    formatter.dateFormat = ProfileDataConstants.weekYearDateFormat
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
            self.handlePostRequest(path: ProfileDataConstants.path, params: params, completion: completion)
        }
    }
}
