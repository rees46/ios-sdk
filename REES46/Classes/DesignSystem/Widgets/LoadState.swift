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
/// Колбэки SDK приходят с фоновой очереди, состояние меняется только на главной.
final class LoadStateMachine<Content> {

    private(set) var state: LoadState<Content> = .idle {
        didSet { onChange?(state) }
    }

    var onChange: ((LoadState<Content>) -> Void)?

    private let fetch: (@escaping (Result<Content, SdkError>) -> Void) -> Void
    private let isEmpty: (Content) -> Bool
    private var generation = 0

    /// - Parameters:
    ///   - fetch: сам запрос; его ответ может прийти с любой очереди.
    ///   - isEmpty: пришедший ответ, в котором нечего показать, — состояние `empty`.
    init(
        fetch: @escaping (@escaping (Result<Content, SdkError>) -> Void) -> Void,
        isEmpty: @escaping (Content) -> Bool
    ) {
        self.fetch = fetch
        self.isEmpty = isEmpty
    }

    /// Новая загрузка; запрос, который ещё в полёте, больше не нужен.
    func load() {
        generation += 1
        let current = generation
        state = .loading
        fetch { [weak self] result in
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

    /// Повтор после ошибки. В других состояниях ничего не делает: идущая загрузка
    /// или пришедший ответ повтора не требуют.
    func retry() {
        guard case .error = state else { return }
        load()
    }

    /// Назад в `idle`; ответ запроса в полёте отбросится.
    func reset() {
        generation += 1
        state = .idle
    }
}
