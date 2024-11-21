public struct PopupActions: Codable {
    let link: Link?
    let close: Close?
    
    struct Link: Codable {
        let link_ios: String?
        let link_android: String?
        let link_web: String?
        let button_text: String?
    }
    
    struct Close: Codable {
        let button_text: String?
    }
}
