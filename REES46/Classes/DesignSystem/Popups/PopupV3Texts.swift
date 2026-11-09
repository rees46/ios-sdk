import Foundation

/// Тексты попапа v3 на случай, когда поле в дизайне пустое (у веба их подставляет компилятор
/// из своих переводов). Русские — при русском первом языке устройства, иначе английские.
struct PopupV3Texts: Equatable {
    var close: String
    var detail: String
    var image: String
    var email: String
    var subscribe: String
    var emailConsent: String
    var emailError: String
    var formError: String
    var send: String
    var copy: String
    var copied: String
    var thanks: String
    var genderMale: String
    var genderFemale: String
    var sendError: String

    static let ru = PopupV3Texts(
        close: "Закрыть",
        detail: "Подробнее",
        image: "Изображение",
        email: "Email",
        subscribe: "Подписаться",
        emailConsent: "Я согласен(на) получать рассылку",
        emailError: "Введите корректный email и отметьте согласие",
        formError: "Заполните обязательные поля",
        send: "Отправить",
        copy: "Скопировать",
        copied: "Скопировано",
        thanks: "Спасибо!",
        genderMale: "Мужской",
        genderFemale: "Женский",
        sendError: "Не удалось отправить. Попробуйте ещё раз"
    )

    static let en = PopupV3Texts(
        close: "Close",
        detail: "Learn more",
        image: "Image",
        email: "Email",
        subscribe: "Subscribe",
        emailConsent: "I agree to receive emails",
        emailError: "Enter a valid email and accept the terms",
        formError: "Fill in the required fields",
        send: "Send",
        copy: "Copy",
        copied: "Copied",
        thanks: "Thank you!",
        genderMale: "Male",
        genderFemale: "Female",
        sendError: "Could not send. Please try again"
    )

    /// По первому языку устройства.
    static var current: PopupV3Texts {
        (Locale.preferredLanguages.first ?? "").lowercased().hasPrefix("ru") ? .ru : .en
    }
}
