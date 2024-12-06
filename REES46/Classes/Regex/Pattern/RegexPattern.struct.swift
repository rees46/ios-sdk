struct RegexPattern {
    static let title = "<div class=\"popup-title\"[^>]*>(.*?)<\\/div>"
    static let subTitle = "<p class=\"popup-\\d+__intro\"[^>]*>(.*?)<\\/p>"
}
