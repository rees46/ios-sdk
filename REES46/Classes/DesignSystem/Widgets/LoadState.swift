import Foundation

/// Состояние виджета с данными.
///
/// Внутреннее: виджет рисует его деталями кита, а наружу отдаёт колбэки. Устроено так,
/// чтобы позже его можно было открыть как есть — для хоста, который рисует сам.
enum LoadState<Content> {
    /// Запроса ещё не было.
    case idle
    case loading
    case content(Content)
    /// Ответ пришёл, но показывать нечего.
    case empty
    case error(SdkError)
}

/// Одна загрузка виджета: `load` ведёт `idle → loading → content | empty | error`,
/// `retry` повторяет её после ошибки.
///
/// Ответ устаревшего запроса — после нового `load` или `reset` — отбрасывается.
/// Состояние меняется только на главной очереди: вызовы с другой очереди и ответы
/// SDK (они приходят с фоновой) перекладываются на неё.
final class LoadStateMachine<Content> {

    private(set) var state: LoadState<Content> = .idle {
        didSet { onChange?(state) }
    }

    var onChange: ((LoadState<Content>) -> Void)?

    private let fetch: (Bool, @escaping (Result<Content, SdkError>) -> Void) -> Void
    private let isEmpty: (Content) -> Bool
    private var generation = 0

    /// - Parameters:
    ///   - fetch: сам запрос; его ответ может прийти с любой очереди. Первый аргумент —
    ///     `force`: это повтор после ошибки, и готовый ответ кэша не годится.
    ///   - isEmpty: пришедший ответ, в котором нечего показать, — состояние `empty`.
    init(
        fetch: @escaping (Bool, @escaping (Result<Content, SdkError>) -> Void) -> Void,
        isEmpty: @escaping (Content) -> Bool
    ) {
        self.fetch = fetch
        self.isEmpty = isEmpty
    }

    /// Новая загрузка; запрос, который ещё в полёте, больше не нужен.
    func load() {
        MainThread.run { self.start(force: false) }
    }

    /// Повтор после ошибки — мимо кэша. В других состояниях ничего не делает: идущая
    /// загрузка или пришедший ответ повтора не требуют.
    func retry() {
        MainThread.run {
            guard case .error = self.state else { return }
            self.start(force: true)
        }
    }

    /// Назад в `idle`; ответ запроса в полёте отбросится.
    func reset() {
        MainThread.run {
            self.generation += 1
            self.state = .idle
        }
    }

    private func start(force: Bool) {
        generation += 1
        let current = generation
        state = .loading
        fetch(force) { [weak self] result in
            MainThread.run {
                guard let self, current == self.generation else { return }
                switch result {
                case .success(let content):
                    self.state = self.isEmpty(content) ? .empty : .content(content)
                case .failure(let error):
                    self.state = .error(error)
                }
            }
        }
    }
}
