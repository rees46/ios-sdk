class UpdateAdvertisingIdUseCase {
    private let advertisingIdPort: AdvertisingIdPort
    private let profileData: ProfileDataProtocol

    init(advertisingIdPort: AdvertisingIdPort, profileData: ProfileDataProtocol) {
        self.advertisingIdPort = advertisingIdPort
        self.profileData = profileData
    }

    func execute(completion: @escaping (Result<AdvertisingId, Error>) -> Void) {
        advertisingIdPort.getAdvertisingId { [weak self] id in
            guard let self = self, let id = id else {
                completion(.failure(AdvertisingError.advertisingIdUnavailable))
                return
            }

            let profile = ProfileData(advertisingId: id) 

            self.profileData.setProfileData(profileData: profile) { result in
                switch result {
                case .success:
                    completion(.success(AdvertisingId(value: id)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
