import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// Code 128 as the kit draws it: code set C for digit strings (with a CODE B switch for an odd last
/// digit), set B for everything else printable, nothing for text the symbology cannot carry. The
/// view snaps its module to whole pixels, so every pixel column is either a bar or a space.
final class PersonalizationBarcodeTests: XCTestCase {

    private func bits<S: Sequence>(_ modules: S) -> String where S.Element == Bool {
        String(modules.map { $0 ? "1" : "0" })
    }

    // MARK: - Encoder

    func testMixedTextUsesCodeSetB() {
        XCTAssertEqual(PersonalizationCode128.values("PJJ123C"), [104, 48, 42, 42, 17, 18, 19, 35, 55], "…, checksum 55")

        guard let modules = PersonalizationCode128.encode("PJJ123C") else { return XCTFail("not encoded") }
        XCTAssertEqual(modules.count, 112)
        XCTAssertEqual(bits(modules.prefix(11)), "11010010000", "Start B")
        XCTAssertEqual(bits(modules.suffix(13)), "1100011101011", "Stop")
    }

    func testAnEvenRunOfDigitsUsesCodeSetC() {
        XCTAssertEqual(PersonalizationCode128.values("1234"), [105, 12, 34, 82], "…, checksum 82")

        guard let modules = PersonalizationCode128.encode("1234") else { return XCTFail("not encoded") }
        XCTAssertEqual(modules.count, 57)
        XCTAssertEqual(bits(modules.prefix(11)), "11010011100", "Start C")
    }

    func testAnOddLastDigitSwitchesToCodeSetB() {
        XCTAssertEqual(PersonalizationCode128.values("123"), [105, 12, 100, 19, 65], "…, CODE B, 3, checksum 65")
        XCTAssertEqual(PersonalizationCode128.encode("123")?.count, 68)
    }

    func testTextCode128CannotCarryIsNotEncoded() {
        XCTAssertNil(PersonalizationCode128.values(""))
        XCTAssertNil(PersonalizationCode128.encode(""))
        XCTAssertNil(PersonalizationCode128.encode("é"))
        XCTAssertNil(PersonalizationCode128.encode("PJJ\n123"), "control characters are outside printable ASCII")
    }

    // MARK: - View

    func testUnencodableTextDrawsNothingAndTakesNoSpace() {
        let barcode = PersonalizationBarcode(code: "é")
        XCTAssertFalse(barcode.hasBars)
        XCTAssertEqual(barcode.intrinsicContentSize, .zero)

        barcode.code = nil
        XCTAssertEqual(barcode.intrinsicContentSize, .zero)
    }

    func testTheModuleIsAWholeNumberOfPixelsWithin232Points() {
        let code = "2000012345678"
        let barcode = PersonalizationBarcode(code: code)
        let scale = barcode.traitCollection.displayScale > 0 ? barcode.traitCollection.displayScale : UIScreen.main.scale
        let count = CGFloat(PersonalizationCode128.encode(code)?.count ?? 0)
        let size = barcode.intrinsicContentSize

        XCTAssertTrue(barcode.hasBars)
        XCTAssertEqual(barcode.accessibilityLabel, code)
        XCTAssertEqual(size.height, 42)
        XCTAssertLessThanOrEqual(size.width, 232)
        let modulePixels = size.width * scale / count
        XCTAssertEqual(modulePixels, modulePixels.rounded(), accuracy: 0.0001, "whole pixels per module")
        XCTAssertEqual(modulePixels, (232 * scale / count).rounded(.down), accuracy: 0.0001, "the widest module that fits")
    }

    func testEveryPixelColumnIsABarOrASpace() {
        let code = "PJJ123C"
        guard let modules = PersonalizationCode128.encode(code) else { return XCTFail("not encoded") }
        let barcode = PersonalizationBarcode(code: code)
        let scale = barcode.traitCollection.displayScale > 0 ? barcode.traitCollection.displayScale : UIScreen.main.scale
        barcode.frame = CGRect(origin: .zero, size: barcode.intrinsicContentSize)

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: barcode.bounds.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(barcode.bounds)
            barcode.draw(barcode.bounds)
        }
        guard let cgImage = image.cgImage, let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return XCTFail("no bitmap") }

        let modulePixels = cgImage.width / modules.count
        XCTAssertEqual(cgImage.width, modules.count * modulePixels)
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let row = cgImage.height / 2 * cgImage.bytesPerRow
        for column in 0..<cgImage.width {
            // Black or white in every channel: the first byte is enough, whatever the order.
            let value = bytes[row + column * bytesPerPixel]
            let expected: UInt8 = modules[column / modulePixels] ? 0 : 255
            XCTAssertEqual(value, expected, "column \(column)")
            if value != expected { break }
        }
    }
}
