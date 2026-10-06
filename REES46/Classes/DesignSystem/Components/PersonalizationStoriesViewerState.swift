import UIKit

/// Логика просмотрщика сторис без UI: где мы (сторис и слайд), куда идти по нажатию
/// и по таймеру, почему стоит пауза, когда сдаться в ожидании медиа.
///
/// Решения возвращаются командами — применяет их просмотрщик: строит слайд, листает
/// сторис, закрывается. Новый слайд просмотрщик сообщает через `enter`, и только тогда
/// меняется положение: так всё, что видно на экране, проходит через одно место.
struct PersonalizationStoriesViewerState {

    /// Почему стоит пауза: отсчёт идёт, только когда причин нет.
    enum PauseReason: Hashable {
        /// Палец держит экран.
        case hold
        /// Свайп вниз или между сторис.
        case drag
        /// Открыт лист товаров.
        case sheet
        /// Приложение или сцена неактивны, экран погас.
        case background
        /// Просмотрщик закрыт другим экраном.
        case hidden
        /// Пауза от хоста (`pause()`).
        case host
        /// Медиа слайда ещё не готово.
        case loading
        /// Медиа не загрузилось — на экране «Повторить».
        case error
    }

    /// Зона нажатия по третям ширины.
    enum Zone: Equatable {
        case previous, center, next
    }

    enum Command: Equatable {
        case none
        /// Слайд текущей сторис.
        case showSlide(Int)
        /// Другая сторис; слайд в ней выбирает просмотрщик по просмотренности.
        case showStory(Int, forward: Bool)
        /// Текущий слайд с начала: и отсчёт, и видео.
        case restartSlide
        case close
        case closeSheet
        /// Медиа не дождались — показать «Повторить».
        case mediaFailed
        /// Видео само пробует ещё раз.
        case retryMedia
    }

    /// Сколько ждать медиа, прежде чем показать «Повторить».
    static let readyTimeout: TimeInterval = 10
    /// Через сколько упавшее видео пробует само.
    static let videoRetryDelay: TimeInterval = 15

    /// Число слайдов каждой сторис.
    let slideCounts: [Int]
    private(set) var story: Int
    private(set) var slide: Int
    private(set) var pauses: Set<PauseReason> = []
    private(set) var isClosing = false
    /// Сколько слайд уже идёт по таймеру.
    private(set) var elapsed: TimeInterval = 0
    /// Сколько ждём медиа.
    private(set) var waited: TimeInterval = 0
    /// Сколько висит «Повторить».
    private(set) var failedFor: TimeInterval = 0

    init(slideCounts: [Int], story: Int = 0, slide: Int = 0) {
        self.slideCounts = slideCounts
        self.story = slideCounts.indices.contains(story) ? story : 0
        self.slide = slide
    }

    var isRunning: Bool { pauses.isEmpty && !isClosing }
    var isSheetOpen: Bool { pauses.contains(.sheet) }
    var isLoading: Bool { pauses.contains(.loading) }
    var hasFailed: Bool { pauses.contains(.error) }
    /// Листать сторис свайпом можно, пока не открыт лист и просмотрщик не закрывается.
    var canSwipe: Bool { !isClosing && !isSheetOpen }

    /// Длина слайда по таймеру. У GIF — не меньше одного круга анимации: короткий круг
    /// повторяется до конца слайда, длинный слайд не обрывает. Круг неизвестен (загрузчик
    /// хоста, GIF не прочитался) или это не GIF — `duration` с сервера.
    static func timerDuration(_ duration: TimeInterval, gifLoop: TimeInterval?) -> TimeInterval {
        guard let gifLoop, gifLoop > 0 else { return duration }
        return max(duration, gifLoop)
    }

    /// Доля прошедшего времени слайда по таймеру.
    func progress(duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(max(elapsed / duration, 0), 1))
    }

    // MARK: - Нажатия и переходы

    /// Левая треть — назад, правая — вперёд, середина — ничего. В RTL края меняются местами.
    static func zone(x: CGFloat, width: CGFloat, rightToLeft: Bool) -> Zone {
        guard width > 0 else { return .center }
        let third = width / 3
        if x < third { return rightToLeft ? .next : .previous }
        if x >= width - third { return rightToLeft ? .previous : .next }
        return .center
    }

    /// Нажатие по слайду. Пока открыт лист товаров, нажатие мимо него только закрывает лист.
    mutating func tap(x: CGFloat, width: CGFloat, rightToLeft: Bool) -> Command {
        guard !isClosing else { return .none }
        if isSheetOpen {
            pauses.remove(.sheet)
            return .closeSheet
        }
        switch Self.zone(x: x, width: width, rightToLeft: rightToLeft) {
        case .previous: return previous()
        case .next: return next()
        case .center: return .none
        }
    }

    /// Следующий слайд, иначе следующая сторис, после последней — закрыть.
    func next() -> Command {
        guard !isClosing else { return .none }
        if slide + 1 < slideCount { return .showSlide(slide + 1) }
        if story + 1 < slideCounts.count { return .showStory(story + 1, forward: true) }
        return .close
    }

    /// Предыдущий слайд, иначе предыдущая сторис; на первом слайде первой — тот же с начала.
    func previous() -> Command {
        guard !isClosing else { return .none }
        if slide > 0 { return .showSlide(slide - 1) }
        if story > 0 { return .showStory(story - 1, forward: false) }
        return .restartSlide
    }

    private var slideCount: Int {
        slideCounts.indices.contains(story) ? slideCounts[story] : 0
    }
}

extension PersonalizationStoriesViewerState {

    // MARK: - Смена слайда

    /// Слайд стал текущим: часы с нуля, лист закрыт, ожидание медиа — заново.
    mutating func enter(slide: Int, mediaReady: Bool) {
        self.slide = slide
        elapsed = 0
        waited = 0
        failedFor = 0
        pauses.subtract([.sheet, .loading, .error])
        if !mediaReady { pauses.insert(.loading) }
    }

    /// Остановилась другая сторис.
    mutating func enter(story: Int, slide: Int, mediaReady: Bool) {
        self.story = story
        enter(slide: slide, mediaReady: mediaReady)
    }

    /// Тот же слайд с начала.
    mutating func restart() {
        elapsed = 0
    }

    // MARK: - Паузы

    mutating func setPaused(_ reason: PauseReason, _ paused: Bool) {
        if paused {
            pauses.insert(reason)
        } else {
            pauses.remove(reason)
        }
    }

    mutating func setSheetOpen(_ open: Bool) {
        setPaused(.sheet, open)
    }

    // MARK: - Медиа

    mutating func mediaReady() {
        pauses.subtract([.loading, .error])
        waited = 0
        failedFor = 0
    }

    mutating func mediaFailed() {
        pauses.remove(.loading)
        pauses.insert(.error)
        failedFor = 0
    }

    /// «Повторить»: снова ждём медиа.
    mutating func retry() {
        pauses.remove(.error)
        pauses.insert(.loading)
        waited = 0
        failedFor = 0
    }

    // MARK: - Часы

    /// Ход времени. `duration` — длина слайда по таймеру; `nil` — время ведёт сам ролик.
    /// В фоне и под чужим экраном не тикают ни отсчёт, ни ожидание медиа.
    mutating func tick(_ delta: TimeInterval, duration: TimeInterval?, isVideo: Bool) -> Command {
        guard !isClosing, delta > 0 else { return .none }
        let counting = !pauses.contains(.background) && !pauses.contains(.hidden)
        if pauses.contains(.loading) {
            guard counting else { return .none }
            waited += delta
            guard waited >= Self.readyTimeout else { return .none }
            mediaFailed()
            return .mediaFailed
        }
        if pauses.contains(.error) {
            guard counting, isVideo else { return .none }
            failedFor += delta
            guard failedFor >= Self.videoRetryDelay else { return .none }
            retry()
            return .retryMedia
        }
        guard pauses.isEmpty, let duration else { return .none }
        elapsed += delta
        return elapsed >= duration ? next() : .none
    }

    /// Закрыть один раз: `false` — уже закрывается.
    mutating func close() -> Bool {
        guard !isClosing else { return false }
        isClosing = true
        return true
    }
}
