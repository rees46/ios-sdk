import UIKit
import ImageIO

// GIF на фоне слайда сторис. Распознаётся по сигнатуре в байтах — не по расширению адреса
// и не по типу слайда. Анимируется только фон слайда; обложки, аватары, постеры и картинки
// товаров показывают первый кадр — его и отдаёт `UIImage(data:)`.

/// Анимированная картинка слайда: сырые байты GIF и длины кадров, без раскодированных
/// кадров. В кэше картинок лежит она; кадры по нескольку вперёд раскодирует
/// `PersonalizationStoryGifPlayer`.
///
/// Длина кадра короче 20 мс (и нулевая) считается за 100 мс — как в браузерах. Один круг
/// анимации — сумма длин кадров; слайд с GIF идёт не меньше одного круга.
final class PersonalizationStoryGif {

    /// Кадр короче этого идёт `fallbackFrameDelay`.
    static let minFrameDelay: TimeInterval = 0.02
    static let fallbackFrameDelay: TimeInterval = 0.1

    let data: Data
    /// Длины кадров по порядку, уже с поправкой на короткие.
    let delays: [TimeInterval]
    /// Размер кадра в пикселях; ноль — ImageIO его не сообщил.
    let pixelSize: CGSize

    var frameCount: Int { delays.count }

    /// Один круг анимации.
    var loopDuration: TimeInterval { delays.reduce(0, +) }

    /// `nil` — это не GIF или в нём нет ни одного читаемого кадра.
    init?(data: Data) {
        guard Self.isGif(data),
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        // Только свойства кадров: пиксели здесь не раскодируются.
        let properties = (0..<count).map { CGImageSourceCopyPropertiesAtIndex(source, $0, nil) as? [CFString: Any] }
        self.data = data
        self.delays = properties.map { frame in
            let gif = frame?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let unclamped = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
            let clamped = (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue
            return Self.frameDelay(unclamped ?? clamped)
        }
        let width = (properties[0]?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (properties[0]?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        self.pixelSize = CGSize(width: width, height: height)
    }

    /// GIF ли это: сигнатура «GIF87a» или «GIF89a» в начале байтов.
    static func isGif(_ data: Data) -> Bool {
        guard data.count >= 6 else { return false }
        let signature = data.prefix(6)
        return signature.elementsEqual("GIF87a".utf8) || signature.elementsEqual("GIF89a".utf8)
    }

    /// Длина кадра по задержке из файла. Задержка в GIF — в сотых секунды; ImageIO отдаёт её
    /// дробью, поэтому сначала округляется до сотых, иначе 2 сотых из `Float` выйдут меньше 20 мс.
    static func frameDelay(_ seconds: TimeInterval?) -> TimeInterval {
        guard let seconds, seconds.isFinite else { return fallbackFrameDelay }
        let rounded = (seconds * 100).rounded() / 100
        return rounded < minFrameDelay ? fallbackFrameDelay : rounded
    }

    /// Предел стороны раскодированного кадра в пикселях: кадр, вписанный в `area` (точки)
    /// при масштабе экрана `scale`. Больше исходника не бывает — кадры только уменьшаются.
    func maxPixelSize(fitting area: CGSize, scale: CGFloat) -> CGFloat {
        let target = CGSize(width: area.width * scale, height: area.height * scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard pixelSize.width > 0, pixelSize.height > 0 else { return max(target.width, target.height) }
        guard target.width > 0, target.height > 0 else { return longest }
        let fit = min(target.width / pixelSize.width, target.height / pixelSize.height, 1)
        return max(1, (longest * fit).rounded(.up))
    }
}
