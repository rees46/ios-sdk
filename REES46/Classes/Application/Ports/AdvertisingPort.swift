public protocol AdvertisingIdPort {
    func getAdvertisingId(completion: @escaping (String?) -> Void)
}
