import UIKit
import ImageIO

/// Часы GIF без UI: какой кадр на экране и сколько он уже показан. Следующий кадр встаёт,
/// только когда он раскодирован, — иначе текущий держится, а не пропускается, и долг
/// времени не копится.
struct PersonalizationStoryGifTimeline {

    /// Длины кадров по порядку.
    let delays: [TimeInterval]
    private(set) var frame = 0
    /// Сколько текущий кадр уже на экране.
    private(set) var shown: TimeInterval = 0

    init(delays: [TimeInterval]) {
        self.delays = delays
    }

    /// Кадр после текущего; после последнего — снова первый.
    var nextFrame: Int {
        delays.isEmpty ? 0 : (frame + 1) % delays.count
    }

    /// Ход времени. `nextReady` — следующий кадр раскодирован. `true` — кадр сменился.
    mutating func advance(_ delta: TimeInterval, nextReady: Bool) -> Bool {
        guard delays.count > 1, delta > 0 else { return false }
        let delay = delays[frame]
        shown += delta
        guard shown >= delay else { return false }
        guard nextReady else {
            // Кадр не готов: текущий стоит, время сверх его длины не копится.
            shown = delay
            return false
        }
        frame = nextFrame
        // Перебор уходит в новый кадр, но не больше его длины: за шаг — не дальше кадра.
        shown = min(shown - delay, delays[frame])
        return true
    }

    /// С первого кадра.
    mutating func restart() {
        frame = 0
        shown = 0
    }
}

/// Проигрыватель GIF фона слайда. `UIImage.animatedImage` не годится — держит все кадры
/// раскодированными и не умеет стоять на кадре; `CGAnimateImageDataWithBlock` — только с iOS 13.
///
/// Кадры раскодируются лениво на фоновой очереди — текущий и `lookahead` вперёд — и сразу
/// уменьшаются до области слайда (`maxPixelSize`, через `CGImageSourceCreateThumbnailAtIndex`).
/// Кроме этого окна держится только первый кадр: с него начинается перезапуск, он виден,
/// пока слайд не на экране. Время ведёт `CADisplayLink` через слабую прокладку; кадры идут
/// со своими длинами, по кругу.
///
/// `pause()` оставляет текущий кадр, `resume()` продолжает с него, `restart()` — с первого
/// кадра без перезагрузки, `rewind()` — встать на первый кадр, `stop()` отпускает всё.
/// Трогать — с главного потока.
final class PersonalizationStoryGifPlayer {

    /// Кто ведёт время: экран или тот, кто зовёт `advance(by:)`.
    enum Clock {
        case displayLink
        case manual
    }

    /// Сколько кадров вперёд держать раскодированными.
    static let lookahead = 2
    /// Самый длинный шаг часов: после паузы кадров анимация не перескакивает.
    static let maxTick: CFTimeInterval = 0.25

    let gif: PersonalizationStoryGif

    /// Кадр для экрана.
    var onFrame: ((UIImage) -> Void)?
    /// Первый кадр отдан на экран.
    var onReady: (() -> Void)?
    /// Первый кадр не раскодировался.
    var onFailure: (() -> Void)?

    private(set) var timeline: PersonalizationStoryGifTimeline
    private(set) var isPlaying = false
    /// Первый кадр на экране.
    private(set) var isReady = false

    var currentFrame: Int { timeline.frame }
    /// Сколько кадров раскодировано прямо сейчас.
    var decodedFrameCount: Int { frames.count }

    private let clock: Clock
    private let decoder: PersonalizationStoryGifDecoder
    private var frames: [Int: UIImage] = [:]
    /// Кадры, которые не раскодировались: вместо них стоит предыдущий.
    private var broken: Set<Int> = []
    private var pending: Set<Int> = []
    /// Растёт при `stop()`: кадры, раскодированные до него, отбрасываются.
    private var generation = 0
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?

    /// `decodesSynchronously` — раскодировать на месте, без очереди (для тестов).
    init(gif: PersonalizationStoryGif, maxPixelSize: CGFloat, clock: Clock = .displayLink, decodesSynchronously: Bool = false) {
        self.gif = gif
        self.clock = clock
        self.timeline = PersonalizationStoryGifTimeline(delays: gif.delays)
        self.decoder = PersonalizationStoryGifDecoder(data: gif.data, maxPixelSize: maxPixelSize, synchronous: decodesSynchronously)
    }

    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - Управление

extension PersonalizationStoryGifPlayer {

    /// Раскодировать первый кадр; когда он на экране — `onReady`.
    func prepare() {
        fill()
    }

    /// Идти с текущего кадра.
    func resume() {
        guard !isPlaying else { return }
        isPlaying = true
        lastTimestamp = nil
        if clock == .displayLink {
            let link = CADisplayLink(target: PersonalizationStoryGifLinkProxy(self), selector: #selector(PersonalizationStoryGifLinkProxy.tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        fill()
    }

    /// Стоять на текущем кадре.
    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
    }

    /// С первого кадра без перезагрузки; идёт, если шёл.
    func restart() {
        timeline.restart()
        lastTimestamp = nil
        if let first = frames[0] { onFrame?(first) }
        fill()
    }

    /// Слайд ушёл с экрана: встать на первый кадр и отпустить остальные.
    func rewind() {
        pause()
        restart()
    }

    /// Всё отпустить: часы, кадры, недораскодированное.
    func stop() {
        pause()
        generation += 1
        frames = [:]
        pending = []
        broken = []
        timeline.restart()
        isReady = false
    }

    /// Ход времени: от экрана или вручную при `Clock.manual`.
    func advance(by delta: TimeInterval) {
        guard isPlaying, isReady else { return }
        let next = timeline.nextFrame
        let nextReady = frames[next] != nil || broken.contains(next)
        guard timeline.advance(delta, nextReady: nextReady) else { return }
        if let image = frames[timeline.frame] { onFrame?(image) }
        fill()
    }

    fileprivate func tick(_ timestamp: CFTimeInterval) {
        let delta = lastTimestamp.map { min(timestamp - $0, Self.maxTick) } ?? 0
        lastTimestamp = timestamp
        advance(by: delta)
    }
}

// MARK: - Окно кадров

extension PersonalizationStoryGifPlayer {

    /// Какие кадры нужны, по порядку важности: текущий, вперёд (только пока идёт), первый.
    private var wantedFrames: [Int] {
        var wanted = [timeline.frame]
        if isPlaying, gif.frameCount > 1 {
            for step in 1...Self.lookahead {
                wanted.append((timeline.frame + step) % gif.frameCount)
            }
        }
        wanted.append(0)
        var seen = Set<Int>()
        return wanted.filter { seen.insert($0).inserted }
    }

    /// Лишние кадры отпускаются, недостающие — в очередь.
    private func fill() {
        let wanted = wantedFrames
        frames = frames.filter { wanted.contains($0.key) }
        for index in wanted where frames[index] == nil && !pending.contains(index) && !broken.contains(index) {
            decode(index)
        }
    }

    private func decode(_ index: Int) {
        pending.insert(index)
        let token = generation
        decoder.decode(index) { [weak self] image in
            guard let self, token == self.generation else { return }
            self.pending.remove(index)
            self.received(image, at: index)
        }
    }

    private func received(_ image: UIImage?, at index: Int) {
        guard let image else {
            broken.insert(index)
            if index == 0, !isReady { onFailure?() }
            return
        }
        // Пока раскодировался, окно ушло дальше.
        guard wantedFrames.contains(index) else { return }
        frames[index] = image
        if index == timeline.frame { onFrame?(image) }
        if index == 0, !isReady {
            isReady = true
            onReady?()
        }
    }
}

/// Раскодировщик кадров на своей очереди: `CGImageSource` трогается только с неё.
/// Ответ — на главном потоке.
final class PersonalizationStoryGifDecoder {

    private let source: CGImageSource?
    private let options: CFDictionary
    private let synchronous: Bool
    private let queue = DispatchQueue(label: "personalization.stories.gif", qos: .userInitiated)

    init(data: Data, maxPixelSize: CGFloat, synchronous: Bool) {
        source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        // Кадр сразу уменьшен до области слайда и уже раскодирован — главный поток его не декодирует.
        options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up)))
        ] as CFDictionary
        self.synchronous = synchronous
    }

    func decode(_ index: Int, completion: @escaping (UIImage?) -> Void) {
        let work = { [weak self] in
            // Проигрыватель ушёл — кадр больше никому не нужен.
            guard let self else { return }
            let image = self.source
                .flatMap { CGImageSourceCreateThumbnailAtIndex($0, index, self.options) }
                .map { UIImage(cgImage: $0) }
            MainThread.run { completion(image) }
        }
        if synchronous {
            work()
        } else {
            queue.async(execute: work)
        }
    }
}

/// Прокладка для `CADisplayLink`: он держит цель сильной ссылкой, а проигрыватель должен уходить сам.
private final class PersonalizationStoryGifLinkProxy: NSObject {
    private weak var player: PersonalizationStoryGifPlayer?

    init(_ player: PersonalizationStoryGifPlayer) {
        self.player = player
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let player else {
            link.invalidate()
            return
        }
        player.tick(link.timestamp)
    }
}
