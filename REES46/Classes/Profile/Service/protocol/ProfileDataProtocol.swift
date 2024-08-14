import Foundation

protocol ProfileDataProtocol{
    
    func setProfileData(
        profileData: ProfileData,
        completion: @escaping (Result<Void, SDKError>) -> Void
    )
}
