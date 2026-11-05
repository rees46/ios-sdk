import UIKit

// Интерактивные элементы попапа v3: подписка на email, форма профиля, промокод и мини-опрос.
// Вид — по стилям дизайна и CSS компилятора (`email_collector.rb`, `form.rb`, `promo_code.rb`,
// `survey.rb`); отправка — через SDK (`PopupV3Actions`). Ошибка сети: форма остаётся, под ней
// текст ошибки, повтор — той же кнопкой; пока запрос в пути, кнопка выключена.

enum PopupV3FormKit {

    static let errorColor = CSSColor(red: 0xb9, green: 0x1c, blue: 0x1c, alpha: 255)

    static func label(_ text: String?, size: Double, weight: Double = 400, family: String? = nil, color: CSSColor,
                      lineHeight: Double? = 1.35, align: NSTextAlignment = .natural) -> PopupV3Label {
        let label = PopupV3Label()
        set(label, text, size: size, weight: weight, family: family, color: color, lineHeight: lineHeight, align: align)
        return label
    }

    static func set(_ label: PopupV3Label, _ text: String?, size: Double, weight: Double = 400, family: String? = nil,
                    color: CSSColor, lineHeight: Double? = 1.35, align: NSTextAlignment = .natural) {
        label.attributedText = PopupV3Fonts.attributed(
            PopupV3Markup.spans(text ?? ""), size: size, weight: weight, family: family,
            color: color, lineHeight: lineHeight, align: align
        )
        label.accessibilityLabel = PopupV3Markup.plain(text ?? "")
    }

    static func stack(_ views: [UIView], axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat, alignment: UIStackView.Alignment = .fill) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = axis
        stack.spacing = spacing
        stack.alignment = alignment
        return stack
    }

    /// Чекбокс кита в цветах формы: отмеченный — как кнопка, пустой — как поле. Попап рисуется по
    /// дизайну, поэтому и чекбокс от темы системы не зависит.
    static func checkbox(button: PopupV3ButtonStyle, input: PopupV3InputStyle) -> PersonalizationCheckbox {
        let checkbox = PersonalizationCheckbox()
        checkbox.checkedColor = button.background.uiColor
        checkbox.checkmarkColor = button.textColor.uiColor
        checkbox.uncheckedColor = input.background.uiColor
        checkbox.uncheckedBorderColor = input.borderColor.uiColor
        return checkbox
    }

    /// Чекбокс кита с подписью; нажатие на подпись тоже переключает.
    static func consent(_ checkbox: PersonalizationCheckbox, label: PopupV3Label) -> UIView {
        let row = stack([checkbox, label], axis: .horizontal, spacing: 8, alignment: .top)
        let tap = PopupV3Tap { [weak checkbox] in
            guard let checkbox else { return }
            checkbox.checkState = checkbox.checkState == .checked ? .unchecked : .checked
            checkbox.sendActions(for: .valueChanged)
        }
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(tap.recognizer)
        objc_setAssociatedObject(label, &PopupV3Tap.key, tap, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return row
    }

    /// Экран успеха формы: заголовок и сообщение.
    static func success(title: String?, message: String?, titleSize: Double, titleColor: CSSColor, size: Double, color: CSSColor,
                        background: CSSColor, align: PopupV3HAlign, radius: Double, paddingX: Double, paddingY: Double) -> UIView {
        let alignment = PopupV3Fonts.alignment(align)
        var views: [UIView] = []
        if let title { views.append(label(title, size: titleSize, weight: 600, color: titleColor, lineHeight: 1.3, align: alignment)) }
        if let message { views.append(label(message, size: size, color: color, lineHeight: 1.4, align: alignment)) }
        let box = PopupV3BoxView(box: PopupV3Box(
            background: background, textColor: color, borderWidth: 0, borderColor: .transparent, borderRadius: radius,
            paddingX: paddingX, paddingY: paddingY, fontFamily: nil, fontSize: size, fontWeight: 400, letterSpacing: 0,
            lineHeight: 1.4, opacity: 1, shadowY: 0, shadowBlur: 0, shadowColor: .transparent
        ))
        box.fill(with: stack(views, spacing: 6))
        box.isHidden = true
        return box
    }

    /// Панель над клавиатурой выбора даты и пола: «Готово» прячет её.
    static func doneBar(for field: UITextField) -> UIToolbar {
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: field, action: #selector(UIResponder.resignFirstResponder))
        bar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), done]
        return bar
    }
}

// MARK: - emailCollector

final class PopupV3EmailView: PopupV3BoxView, UITextFieldDelegate {

    let spec: PopupV3EmailSpec
    let field: PopupV3TextField
    let submit: PopupV3ButtonControl
    let checkbox: PersonalizationCheckbox
    let status: PopupV3Label
    private let form: UIStackView
    private let success: UIView
    private let context: PopupV3RenderContext?
    private(set) var isBusy = false

    init(element: PopupV3Element, context: PopupV3RenderContext) {
        let spec = PopupV3EmailSpec(element, texts: context.texts, runtime: context.runtime)
        let checkbox = PopupV3FormKit.checkbox(button: spec.button, input: spec.input)
        self.checkbox = checkbox
        let box = element.box
        self.spec = spec
        self.context = context
        field = PopupV3TextField(style: spec.input, fontSize: spec.inputFontSize, paddingY: spec.button.paddingY, placeholder: PopupV3Markup.plain(spec.placeholder))
        submit = PopupV3ButtonControl(text: spec.submitText, style: spec.button, family: box.fontFamily, weight: 500, lineHeight: 1.25)
        status = PopupV3FormKit.label(nil, size: 12, color: PopupV3FormKit.errorColor)
        let consentLabel = PopupV3FormKit.label(spec.consentLabel, size: 11, family: box.fontFamily, color: box.textColor)
        let row = PopupV3FormKit.stack([field, submit], axis: spec.inline ? .horizontal : .vertical, spacing: 8)
        form = PopupV3FormKit.stack([row, PopupV3FormKit.consent(checkbox, label: consentLabel), status], spacing: 8)
        success = PopupV3FormKit.success(
            title: spec.successTitle, message: spec.successMessage, titleSize: spec.successTitleFontSize, titleColor: spec.successTitleColor,
            size: spec.successFontSize, color: spec.successColor, background: spec.successBackground, align: spec.successAlign,
            radius: spec.successRadius, paddingX: spec.successPaddingX, paddingY: spec.successPaddingY
        )
        super.init(box: box)
        status.isHidden = true
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .send
        if #available(iOS 11.0, *) { field.textContentType = .emailAddress }
        field.delegate = self
        field.accessibilityIdentifier = "popupV3.email"
        submit.setContentHuggingPriority(.required, for: .horizontal)
        submit.setContentCompressionResistancePriority(.required, for: .horizontal)
        submit.label.setContentCompressionResistancePriority(.required, for: .horizontal)
        submit.popupV3OnTap { [weak self] in self?.send() }
        fill(with: PopupV3FormKit.stack([form, success], spacing: 0))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        send()
        return true
    }

    /// Согласие отмечено и email по формату — подписка, затем сегмент, события и экран успеха.
    func send() {
        guard !isBusy, let actions = context?.actions else { return }
        let email = (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard checkbox.checkState == .checked, PopupV3Validation.isEmail(email) else {
            return show(error: spec.errorMessage)
        }
        show(error: nil)
        setBusy(true)
        actions.subscribe(email: email, consents: spec.consentFields) { [weak self] ok in
            guard let self else { return }
            guard ok else {
                self.setBusy(false)
                return self.show(error: self.context?.texts.sendError)
            }
            let finish = { [weak self] in
                guard let self else { return }
                actions.event("subscribe", channel: "email")
                actions.event("submit", channel: nil)
                self.setBusy(false)
                self.field.resignFirstResponder()
                if self.spec.hasSuccess {
                    self.form.isHidden = true
                    self.success.isHidden = false
                } else {
                    self.field.text = nil
                }
                actions.relayout()
            }
            if let segment = self.spec.segmentId {
                actions.addToSegment(segment) { _ in finish() }
            } else {
                finish()
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        submit.isEnabled = !busy
    }

    private func show(error: String?) {
        PopupV3FormKit.set(status, error, size: 12, color: PopupV3FormKit.errorColor)
        status.isHidden = error == nil
        context?.actions?.relayout()
        if error != nil { context?.actions?.reveal(status) }
    }

    var isShowingSuccess: Bool { !success.isHidden }
    var errorText: String? { status.isHidden ? nil : status.attributedText?.string }
}

// MARK: - form

final class PopupV3FormView: PopupV3BoxView, UITextFieldDelegate {

    /// Поле формы и его ввод.
    final class Input {
        let field: PopupV3FormSpec.Field
        let textField: PopupV3TextField
        /// Значение для профиля: у даты — `YYYY-MM-DD`, у пола — `m`/`f`.
        var value: String?

        init(field: PopupV3FormSpec.Field, textField: PopupV3TextField) {
            self.field = field
            self.textField = textField
        }

        var current: String {
            switch field.kind {
            case .birthday, .gender: return value ?? ""
            default: return (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    let spec: PopupV3FormSpec
    private(set) var inputs: [Input] = []
    let checkbox: PersonalizationCheckbox
    let submit: PopupV3ButtonControl
    let status: PopupV3Label
    private let form: UIStackView
    private let success: UIView
    private let context: PopupV3RenderContext?
    private(set) var isBusy = false
    private var hasConsent = false

    init(element: PopupV3Element, context: PopupV3RenderContext) {
        let spec = PopupV3FormSpec(element, texts: context.texts, runtime: context.runtime)
        let box = element.box
        let checkbox = PopupV3FormKit.checkbox(button: spec.button, input: spec.input)
        self.checkbox = checkbox
        self.spec = spec
        self.context = context
        submit = PopupV3ButtonControl(text: spec.submitText, style: spec.button, family: box.fontFamily, weight: 500, lineHeight: 1.25)
        status = PopupV3FormKit.label(nil, size: 12, color: PopupV3FormKit.errorColor)
        var rows: [UIView] = []
        var inputs: [Input] = []
        for field in spec.fields {
            let textField = PopupV3TextField(style: spec.input, fontSize: spec.inputFontSize, paddingY: spec.button.paddingY, placeholder: PopupV3Markup.plain(field.placeholder))
            textField.accessibilityIdentifier = "popupV3.field.\(field.id)"
            let input = Input(field: field, textField: textField)
            inputs.append(input)
            var views: [UIView] = []
            if !field.label.isEmpty {
                views.append(PopupV3FormKit.label(field.label + (field.required ? " *" : ""), size: 11, family: box.fontFamily, color: box.textColor))
            }
            views.append(textField)
            rows.append(PopupV3FormKit.stack(views, spacing: 4))
        }
        let consentText = spec.consentLabel ?? (spec.consentFields.isEmpty ? nil : context.texts.emailConsent)
        if let consentText {
            rows.append(PopupV3FormKit.consent(checkbox, label: PopupV3FormKit.label(consentText, size: 11, family: box.fontFamily, color: box.textColor)))
        }
        rows.append(status)
        rows.append(submit)
        form = PopupV3FormKit.stack(rows, spacing: 8)
        success = PopupV3FormKit.success(
            title: spec.successTitle, message: spec.successMessage, titleSize: 16, titleColor: box.textColor,
            size: 13, color: box.textColor, background: .transparent, align: .center, radius: 0, paddingX: 0, paddingY: 0
        )
        super.init(box: box)
        hasConsent = consentText != nil
        self.inputs = inputs
        status.isHidden = true
        inputs.forEach(configure)
        submit.popupV3OnTap { [weak self] in self?.send() }
        fill(with: PopupV3FormKit.stack([form, success], spacing: 0))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(_ input: Input) {
        let textField = input.textField
        textField.delegate = self
        textField.returnKeyType = .next
        switch input.field.kind {
        case .email:
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            if #available(iOS 11.0, *) { textField.textContentType = .emailAddress }
        case .phone:
            textField.keyboardType = .phonePad
            if #available(iOS 11.0, *) { textField.textContentType = .telephoneNumber }
        case .firstName:
            if #available(iOS 11.0, *) { textField.textContentType = .givenName }
        case .lastName:
            if #available(iOS 11.0, *) { textField.textContentType = .familyName }
        case .birthday:
            let picker = UIDatePicker()
            picker.datePickerMode = .date
            picker.maximumDate = Date()
            if #available(iOS 13.4, *) { picker.preferredDatePickerStyle = .wheels }
            picker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
            textField.inputView = picker
            textField.inputAccessoryView = PopupV3FormKit.doneBar(for: textField)
        case .gender:
            let picker = UIPickerView()
            picker.dataSource = self
            picker.delegate = self
            textField.inputView = picker
            textField.inputAccessoryView = PopupV3FormKit.doneBar(for: textField)
        case .custom:
            break
        }
    }

    @objc private func dateChanged(_ picker: UIDatePicker) {
        guard let input = inputs.first(where: { $0.field.kind == .birthday && $0.textField.inputView === picker }) else { return }
        input.value = Self.wireDate(picker.date)
        input.textField.text = Self.shownDate(picker.date)
    }

    static func wireDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func shownDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Дата выбирается сразу, без прокрутки колеса: пустое поле получает сегодняшнюю.
        if let input = inputs.first(where: { $0.textField === textField }), input.field.kind == .birthday, input.value == nil,
           let picker = textField.inputView as? UIDatePicker {
            dateChanged(picker)
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let index = inputs.firstIndex(where: { $0.textField === textField }), index + 1 < inputs.count {
            _ = inputs[index + 1].textField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Дата и пол — только из выбора.
        guard let input = inputs.first(where: { $0.textField === textField }) else { return true }
        return input.field.kind != .birthday && input.field.kind != .gender
    }

    /// Ошибка проверки: обязательное пустое, email или телефон не по формату. `nil` — всё верно.
    func validationError() -> String? {
        for input in inputs {
            let value = input.current
            if input.field.required && value.isEmpty { return spec.errorMessage }
            if !value.isEmpty, input.field.kind == .email, !PopupV3Validation.isEmail(value) { return spec.errorMessage }
            if !value.isEmpty, input.field.kind == .phone, !PopupV3Validation.isPhone(value) { return spec.errorMessage }
        }
        return nil
    }

    /// Профиль из заполненных полей; пустые не отправляются.
    func profile() -> PopupV3Profile {
        var profile = PopupV3Profile()
        for input in inputs {
            let value = input.current
            guard !value.isEmpty else { continue }
            switch input.field.kind {
            case .email: profile.email = value
            case .phone: profile.phone = value
            case .firstName: profile.firstName = value
            case .lastName: profile.lastName = value
            case .birthday: profile.birthday = value
            case .gender: profile.gender = value
            case .custom:
                if !input.field.propertyKey.isEmpty { profile.custom[input.field.propertyKey] = value }
            }
        }
        return profile
    }

    func send() {
        guard !isBusy, let actions = context?.actions else { return }
        if let error = validationError() { return show(error: error) }
        show(error: nil)
        endEditing(true)
        setBusy(true)
        let profile = self.profile()
        actions.saveProfile(profile) { [weak self] ok in
            guard let self else { return }
            guard ok else {
                self.setBusy(false)
                return self.show(error: self.context?.texts.sendError)
            }
            let consented = self.hasConsent && self.checkbox.checkState == .checked && !self.spec.consentFields.isEmpty
            let segment = { [weak self] in
                guard let self else { return }
                let finish = { [weak self] in
                    guard let self else { return }
                    actions.event("submit", channel: nil)
                    self.setBusy(false)
                    if self.spec.hasSuccess {
                        self.form.isHidden = true
                        self.success.isHidden = false
                    }
                    actions.relayout()
                }
                if let id = self.spec.segmentId { actions.addToSegment(id) { _ in finish() } } else { finish() }
            }
            if consented, let email = profile.email {
                actions.subscribe(email: email, consents: self.spec.consentFields) { _ in segment() }
            } else {
                segment()
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        submit.isEnabled = !busy
    }

    private func show(error: String?) {
        PopupV3FormKit.set(status, error, size: 12, color: PopupV3FormKit.errorColor)
        status.isHidden = error == nil
        context?.actions?.relayout()
        if error != nil { context?.actions?.reveal(status) }
    }

    var isShowingSuccess: Bool { !success.isHidden }
    var errorText: String? { status.isHidden ? nil : status.attributedText?.string }
}

extension PopupV3FormView: UIPickerViewDataSource, UIPickerViewDelegate {

    private var genders: [(value: String?, title: String)] {
        let texts = context?.texts ?? .current
        return [(nil, "—"), ("m", texts.genderMale), ("f", texts.genderFemale)]
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { genders.count }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { genders[row].title }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let input = inputs.first(where: { $0.field.kind == .gender && $0.textField.inputView === pickerView }) else { return }
        let option = genders[row]
        input.value = option.value
        input.textField.text = option.value == nil ? nil : option.title
    }
}

// MARK: - promoCode

final class PopupV3PromoView: PopupV3BoxView {

    let spec: PopupV3PromoSpec
    let codeLabel: UILabel
    let copyButton: UIButton?
    private let context: PopupV3RenderContext?

    init(element: PopupV3Element, context: PopupV3RenderContext) {
        let spec = PopupV3PromoSpec(element, texts: context.texts, runtime: context.runtime)
        let box = element.box
        self.spec = spec
        self.context = context
        codeLabel = UILabel()
        codeLabel.attributedText = NSAttributedString(string: spec.code, attributes: [
            .font: PopupV3Fonts.font(size: spec.codeFontSize, weight: 700, family: "monospace"),
            .foregroundColor: spec.codeColor.uiColor,
            .kern: 1
        ])
        codeLabel.numberOfLines = 0
        codeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        codeLabel.accessibilityIdentifier = "popupV3.promo.code"
        var codeViews: [UIView] = [codeLabel]
        if spec.showCopy {
            let button = UIButton(type: .system)
            button.setAttributedTitle(Self.copyTitle(spec.copyText, color: spec.codeColor), for: .normal)
            button.contentEdgeInsets = .zero
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.accessibilityIdentifier = "popupV3.promo.copy"
            codeViews.append(button)
            copyButton = button
        } else {
            copyButton = nil
        }
        super.init(box: box)
        let code = PopupV3FormKit.stack(codeViews, axis: .horizontal, spacing: 10, alignment: .center)
        let codeBox = PopupV3BoxView(box: PopupV3Box(
            background: spec.codeBackground, textColor: spec.codeColor, borderWidth: 0, borderColor: .transparent,
            borderRadius: spec.codeRadius, paddingX: 14, paddingY: 8, fontFamily: "monospace", fontSize: spec.codeFontSize,
            fontWeight: 700, letterSpacing: 1, lineHeight: 1.35, opacity: 1, shadowY: 0, shadowBlur: 0, shadowColor: .transparent
        ))
        codeBox.fill(with: code)
        var column: [UIView] = []
        if let label = spec.label {
            let text = PopupV3TextSpec(element, runtime: context.runtime)
            column.append(PopupV3FormKit.label(label, size: text.fontSize, weight: text.fontWeight, family: box.fontFamily,
                                               color: box.textColor, lineHeight: box.lineHeight, align: PopupV3Fonts.alignment(spec.align)))
        }
        column.append(codeBox)
        let alignment: UIStackView.Alignment
        switch spec.align {
        case .left: alignment = .leading
        case .center: alignment = .center
        case .right: alignment = .trailing
        }
        fill(with: PopupV3FormKit.stack(column, spacing: 6, alignment: alignment))
        copyButton?.popupV3OnTap { [weak self] in self?.copyCode() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func copyTitle(_ text: String, color: CSSColor) -> NSAttributedString {
        NSAttributedString(string: PopupV3Markup.plain(text), attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: color.uiColor.withAlphaComponent(0.8 * CGFloat(color.alpha) / 255)
        ])
    }

    /// Код в буфер, «Скопировано», событие `click`, затем ссылка применения, если задана.
    func copyCode() {
        guard let actions = context?.actions else { return }
        actions.copy(spec.code, toast: nil)
        copyButton?.setAttributedTitle(Self.copyTitle(spec.copiedText, color: spec.codeColor), for: .normal)
        actions.event("click", channel: nil)
        if let href = spec.applyHref { actions.open(href) }
    }
}

// MARK: - survey

final class PopupV3SurveyView: PopupV3BoxView {

    let spec: PopupV3SurveySpec
    private(set) var scores: [PopupV3ButtonControl] = []
    let comment: PopupV3TextView
    let submit: PopupV3ButtonControl
    let status: PopupV3Label
    let thanks: PopupV3Label
    private let question: UIView?
    private let scale = PersonalizationFlowView(horizontalGap: 6, verticalGap: 6)
    private let labels: UIView?
    private let form: UIStackView
    private let context: PopupV3RenderContext?
    private(set) var selected: Int?
    private(set) var isBusy = false
    private let family: String?

    init(element: PopupV3Element, context: PopupV3RenderContext) {
        let spec = PopupV3SurveySpec(element, texts: context.texts, runtime: context.runtime)
        let box = element.box
        let comment = PopupV3TextView()
        self.comment = comment
        self.spec = spec
        self.context = context
        family = box.fontFamily
        question = spec.question.map {
            PopupV3FormKit.label($0, size: box.fontSize, weight: 600, family: box.fontFamily, color: box.textColor, lineHeight: box.lineHeight)
        }
        if spec.minLabel != nil || spec.maxLabel != nil {
            let min = PopupV3FormKit.label(spec.minLabel, size: 11, family: box.fontFamily, color: box.textColor)
            let max = PopupV3FormKit.label(spec.maxLabel, size: 11, family: box.fontFamily, color: box.textColor, align: .right)
            let row = PopupV3FormKit.stack([min, max], axis: .horizontal, spacing: 8, alignment: .top)
            row.distribution = .fillEqually
            row.alpha = 0.7
            labels = row
        } else {
            labels = nil
        }
        submit = PopupV3ButtonControl(text: spec.submitText, style: spec.button, family: box.fontFamily, weight: 500, lineHeight: 1.25)
        status = PopupV3FormKit.label(nil, size: 12, color: PopupV3FormKit.errorColor)
        thanks = PopupV3FormKit.label(spec.thanksText, size: box.fontSize, weight: 600, family: box.fontFamily, color: box.textColor, lineHeight: box.lineHeight)
        let submitRow = PopupV3FormKit.stack([submit, UIView()], axis: .horizontal, spacing: 0)
        submit.setContentHuggingPriority(.required, for: .horizontal)
        form = PopupV3FormKit.stack([comment, submitRow, status], spacing: 8)
        super.init(box: box)
        comment.placeholder = spec.commentPlaceholder.map(PopupV3Markup.plain)
        status.isHidden = true
        form.isHidden = true
        thanks.isHidden = true
        scores = spec.scale.map { score in
            let style = PopupV3ButtonStyle(background: spec.scaleBackground, textColor: spec.scaleColor, fontSize: 13, radius: 8, paddingX: 6, paddingY: 0)
            let button = PopupV3ButtonControl(text: String(score), style: style, family: box.fontFamily, weight: 600)
            button.accessibilityIdentifier = "popupV3.survey.\(score)"
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: 30),
                button.widthAnchor.constraint(greaterThanOrEqualToConstant: 30)
            ])
            button.popupV3OnTap { [weak self] in self?.select(score) }
            return button
        }
        scale.setItems(scores)
        submit.popupV3OnTap { [weak self] in self?.send() }
        let column = PopupV3FormKit.stack([question, scale, labels, form, thanks].compactMap { $0 }, spacing: 10)
        fill(with: column)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Оценка выбрана: подсветка и поле комментария с кнопкой.
    func select(_ score: Int) {
        guard !isBusy else { return }
        selected = score
        for (index, button) in scores.enumerated() {
            let active = spec.scale.lowerBound + index == score
            let style = PopupV3ButtonStyle(
                background: active ? spec.activeBackground : spec.scaleBackground,
                textColor: active ? spec.activeColor : spec.scaleColor,
                fontSize: 13, radius: 8, paddingX: 6, paddingY: 0
            )
            button.layer.backgroundColor = style.background.uiColor.cgColor
            button.label.attributedText = PopupV3Fonts.attributed(
                PopupV3Markup.spans(String(spec.scale.lowerBound + index)), size: 13, weight: 600, family: family,
                color: style.textColor, lineHeight: nil, align: .center
            )
        }
        if form.isHidden {
            form.isHidden = false
            context?.actions?.relayout()
        }
    }

    /// Отзыв в API v3 опросов; ответ принят — «спасибо» вместо опроса.
    func send() {
        guard !isBusy, let rate = selected, let actions = context?.actions else { return }
        isBusy = true
        submit.isEnabled = false
        status.isHidden = true
        comment.resignFirstResponder()
        actions.review(kind: spec.kind, body: spec.body(rate: rate, comment: comment.text)) { [weak self] ok in
            guard let self else { return }
            self.isBusy = false
            self.submit.isEnabled = true
            if ok {
                actions.event("submit", channel: nil)
                [self.question, self.scale, self.labels, self.form].forEach { $0?.isHidden = true }
                self.thanks.isHidden = false
            } else {
                PopupV3FormKit.set(self.status, self.context?.texts.sendError, size: 12, color: PopupV3FormKit.errorColor)
                self.status.isHidden = false
            }
            actions.relayout()
            if !ok { actions.reveal(self.status) }
        }
    }

    var isShowingThanks: Bool { !thanks.isHidden }
    var errorText: String? { status.isHidden ? nil : status.attributedText?.string }
    var isFormShown: Bool { !form.isHidden }
}

/// Поле комментария опроса: три строки, рамка #cbd5e1, радиус 10, подсказка.
final class PopupV3TextView: UITextView, UITextViewDelegate {

    private let hint = UILabel()

    var placeholder: String? {
        didSet { hint.text = placeholder }
    }

    init() {
        super.init(frame: .zero, textContainer: nil)
        font = .systemFont(ofSize: 13)
        textColor = UIColor(red: 0x11 / 255, green: 0x18 / 255, blue: 0x27 / 255, alpha: 1)
        backgroundColor = .white
        layer.borderWidth = 1
        layer.borderColor = CSSColor(red: 0xcb, green: 0xd5, blue: 0xe1, alpha: 255).uiColor.cgColor
        layer.cornerRadius = 10
        textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        self.textContainer.lineFragmentPadding = 0
        isScrollEnabled = false
        delegate = self
        accessibilityIdentifier = "popupV3.survey.comment"
        hint.font = .systemFont(ofSize: 13)
        hint.textColor = UIColor.gray
        hint.numberOfLines = 1
        hint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hint)
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            hint.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            hint.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -24),
            heightAnchor.constraint(greaterThanOrEqualToConstant: ceil(UIFont.systemFont(ofSize: 13).lineHeight * 3 + 16))
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textViewDidChange(_ textView: UITextView) {
        hint.isHidden = !text.isEmpty
    }

    override func becomeFirstResponder() -> Bool {
        if let window, !window.isKeyWindow { window.makeKey() }
        return super.becomeFirstResponder()
    }
}
