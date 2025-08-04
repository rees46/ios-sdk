public protocol AdvertisingIdPort {
    func getAdvertisingId(completion: @escaping (AdvertisingId?) -> Void)
}
