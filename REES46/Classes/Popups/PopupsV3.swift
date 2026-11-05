import UIKit

/// Попапы v3 — нативный рендер документа design нового конструктора попапов.
///
/// Спящий режим: движок не шлёт ни одного запроса, пока хост не включил его (`isEnabled`) и
/// `/init` не прислал флаг `popups_v3` (или хост велел флаг не ждать — `ignoreInitFlag`).
/// Хост сообщает об открытых экранах (`screenOpened`) именами, которые маркетолог пишет в
/// `target_screens`. Всё — за шлюзом кита, публичное API SDK не меняется.
///
///     sdk.popups.appHost = "app.rees46.ru"
///     sdk.popups.isEnabled = true
///     sdk.popups.screenOpened("product")
///     sdk.popups.show(id: 512)
@_spi(PersonalizationUI) public final class PersonalizationPopups {

    /// Хост ЛК (API v3) по умолчанию.
    public static let defaultAppHost = "app.rees46.ru"

    /// Включить движок. Без этого — ни одного запроса.
    public var isEnabled: Bool {
        get { state.enabled }
        set { state.enabled = newValue; onMain { $0.engine.enabled = newValue } }
    }

    /// Не ждать флага `popups_v3` из `/init` (демо, отладка): движок работает и без него.
    public var ignoreInitFlag: Bool {
        get { state.ignoreInitFlag }
        set { state.ignoreInitFlag = newValue; onMain { $0.engine.ignoreInitFlag = newValue } }
    }

    /// Тестовый режим: в запросы — `testmode=true` (попапы в статусе «Тест»), частота не пишется.
    public var testMode: Bool {
        get { state.testMode }
        set { state.testMode = newValue; onMain { $0.engine.testMode = newValue } }
    }

    /// Отладка: `debug=1` в запросе списка и решения движка в лог.
    public var debug: Bool {
        get { state.debug }
        set { state.debug = newValue; onMain { $0.engine.debug = newValue } }
    }

    /// Хост ЛК без схемы, например `app.rees46.ru`.
    public var appHost: String {
        get { state.appHost }
        set { state.appHost = newValue }
    }

    /// Ссылки попапа (кнопка-ссылка, ссылка текста и картинки, ссылка применения промокода, ссылка
    /// товара ленты) сначала идут сюда: `true` — хост открыл сам, попап закрывается (без события
    /// `close`, как после перехода); иначе — `UIApplication.open`, попап остаётся.
    public var linkHandler: ((URL) -> Bool)? {
        get { state.linkHandler }
        set { state.linkHandler = newValue }
    }

    /// Нажатие на товар ленты рекомендаций: `true` — хост открыл товар сам, попап закрывается
    /// (без события `close`, как после перехода); иначе — ссылка товара (`deeplink`, потом `url`)
    /// через `linkHandler` и систему.
    public var productHandler: ((PersonalizationProduct) -> Bool)? {
        get { state.productHandler }
        set { state.productHandler = newValue }
    }

    /// Хост открыл экран `name` — триггеры `screen_open`, `time_on_screen` и ожидающие `app_start`.
    public func screenOpened(_ name: String) {
        onMain { $0.engine.screenOpened(name) }
    }

    /// Ручной показ попапа по id: без триггера, экранов и частоты.
    public func show(id: Int) {
        onMain { $0.engine.show(id: id) }
    }

    // MARK: - Внутреннее

    /// Настройки хоста; читаются с любого потока.
    private struct State {
        var enabled = false
        var ignoreInitFlag = false
        var testMode = false
        var debug = false
        var appHost = PersonalizationPopups.defaultAppHost
        var linkHandler: ((URL) -> Bool)?
        var productHandler: ((PersonalizationProduct) -> Bool)?
    }

    private let lock = NSLock()
    private var storedState = State()
    private var state: State {
        get { lock.lock(); defer { lock.unlock() }; return storedState }
        set { lock.lock(); storedState = newValue; lock.unlock() }
    }

    private weak var sdkObject: AnyObject?
    private var observers: [NSObjectProtocol] = []

    /// Создаётся на главном потоке при первом обращении.
    private lazy var engine: PopupsV3Engine = makeEngine()

    init(sdk: (PersonalizationSDK & AnyObject)?) {
        self.sdkObject = sdk
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private var sdk: PersonalizationSDK? { sdkObject as? PersonalizationSDK }

    private func makeEngine() -> PopupsV3Engine {
        let sdkObject = self.sdkObject
        let apiHost = (sdkObject as? SimplePersonalizationSDK)?.baseURL ?? "https://api.rees46.ru/"
        let backend: PopupsV3Backend
        if let sdk = sdkObject as? PersonalizationSDK & AnyObject {
            backend = PopupsV3API(sdk: sdk, appHost: { [weak self] in self?.appHost ?? PersonalizationPopups.defaultAppHost }, apiHost: apiHost)
        } else {
            backend = PopupsV3OfflineBackend()
        }
        let presenter = PopupV3WindowPresenter(
            sdk: sdkObject,
            appHost: { [weak self] in self?.appHost ?? PersonalizationPopups.defaultAppHost },
            linkHandler: { [weak self] in self?.linkHandler },
            productHandler: { [weak self] in self?.productHandler }
        )
        let shopId = (sdkObject as? PersonalizationSDK)?.shopId ?? ""
        let frequency = PopupsV3Frequency(
            defaults: StoragePartition.store(for: shopId),
            now: Date.init,
            sid: { (sdkObject as? PersonalizationSDK)?.userSeance ?? "" },
            testMode: { [weak self] in self?.testMode ?? false }
        )
        let engine = PopupsV3Engine(
            backend: backend, presenter: presenter, clock: PopupsV3SystemClock(), frequency: frequency,
            sid: { (sdkObject as? PersonalizationSDK)?.userSeance ?? "" }
        )
        engine.autoPresentation = { (sdkObject as? PersonalizationSDK)?.enableAutoPopupPresentation ?? true }
        let state = self.state
        engine.debug = state.debug
        engine.testMode = state.testMode
        engine.ignoreInitFlag = state.ignoreInitFlag
        engine.enabled = state.enabled
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak engine] _ in
                engine?.enteredBackground()
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak engine] _ in
                engine?.enteredForeground()
            },
            center.addObserver(forName: .personalizationLegacyPopupClosed, object: nil, queue: .main) { [weak engine] _ in
                engine?.processQueue()
            },
            center.addObserver(forName: .personalizationPopupsV3SlotFreed, object: nil, queue: .main) { [weak engine] _ in
                engine?.processQueue()
            }
        ]
        return engine
    }

    private func onMain(_ body: @escaping (PersonalizationPopups) -> Void) {
        MainThread.run { [weak self] in
            guard let self else { return }
            body(self)
        }
    }

    /// `/init` закончился: флаг `popups_v3` ответа.
    func initFinished(flag: Bool) {
        onMain { $0.engine.initFinished(flag: flag) }
    }

    /// Кастомное событие SDK (`trackEvent`, `tracking.custom`) — триггер `track_event`.
    func trackEvent(_ name: String) {
        onMain { $0.engine.trackEvent(name) }
    }

    /// Покупка — список заново.
    func purchased() {
        onMain { $0.engine.purchased() }
    }

    /// Профиль, подписка или сегмент — список заново, если данные новые для сеанса.
    func contextChanged(_ kind: String, signature: String) {
        onMain { $0.engine.contextChanged(kind, signature: signature) }
    }
}

/// Сеть без SDK: списка нет, показывать нечего.
private final class PopupsV3OfflineBackend: PopupsV3Backend {
    func fetchList(testMode: Bool, debug: Bool, completion: @escaping (PopupsV3ListResult) -> Void) { completion(.failure) }
    func fetchPopup(id: Int, testMode: Bool, completion: @escaping (PopupV3?) -> Void) { completion(nil) }
    func sendEvent(popupId: Int, event: String, channel: String?) {}
    func fetchPromoCode(listId: String, completion: @escaping (String?) -> Void) { completion(nil) }
}

extension PersonalizationSDK {

    /// Попапы v3 этого инстанса.
    @_spi(PersonalizationUI) public var popups: PersonalizationPopups {
        (self as? SimplePersonalizationSDK)?.popupsV3 ?? PersonalizationPopups.detached
    }
}

extension PersonalizationPopups {
    /// Для чужих реализаций протокола SDK (подмены в тестах): ничего не показывает.
    static let detached = PersonalizationPopups(sdk: nil)
}
