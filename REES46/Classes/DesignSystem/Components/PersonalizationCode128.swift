import Foundation

/// Кодировщик штрихкода Code 128 — то, что рисует `PersonalizationBarcode`.
///
/// Номер карты лояльности в макете (Wallet/Code, 520:8886) — линейный штрихкод, а Code 128 —
/// формат, который читают кассовые сканеры и Apple Wallet. Библиотеку ради сотни строк
/// таблицы SDK не тянет.
///
/// Набор выбирается целиком на строку: одни цифры — набор C (две цифры на символ, код вдвое
/// короче), при нечётной длине последняя цифра уходит в набор B через переключатель CODE B.
/// Всё прочее — набор B, печатный ASCII 32…126. Строку с другими символами Code 128 без
/// расширений не несёт — тогда кодировщик возвращает nil, и штрихкода нет.
enum PersonalizationCode128 {

    /// Символы строки: значения по порядку, от старт-символа до контрольного включительно.
    static func values(_ text: String) -> [Int]? {
        let codes = text.unicodeScalars.map { $0.value }
        guard !codes.isEmpty, codes.allSatisfy({ printable.contains($0) }) else { return nil }
        var values: [Int] = []
        if codes.count >= 2, codes.allSatisfy({ (48...57).contains($0) }) {
            let digits = codes.map { Int($0) - 48 }
            values.append(startC)
            for pair in 0..<(digits.count / 2) {
                values.append(digits[pair * 2] * 10 + digits[pair * 2 + 1])
            }
            if let last = codes.last, codes.count % 2 == 1 {
                values.append(codeB)
                values.append(Int(last) - 32)
            }
        } else {
            values.append(startB)
            values.append(contentsOf: codes.map { Int($0) - 32 })
        }
        values.append(checksum(values))
        return values
    }

    /// Модули слева направо, `true` — штрих. Тихих зон по краям нет — их даёт подложка.
    static func encode(_ text: String) -> [Bool]? {
        guard let symbols = values(text) else { return nil }
        var modules: [Bool] = []
        modules.reserveCapacity(symbols.count * 11 + 13)
        for value in symbols + [stop] {
            for (index, width) in patterns[value].enumerated() {
                let bar = index % 2 == 0
                modules.append(contentsOf: repeatElement(bar, count: width.wholeNumberValue ?? 0))
            }
        }
        return modules
    }

    /// Старт-символ плюс сумма значений, взвешенных позицией с единицы, по модулю 103.
    private static func checksum(_ values: [Int]) -> Int {
        var sum = values[0]
        for index in 1..<values.count {
            sum += index * values[index]
        }
        return sum % 103
    }

    private static let printable: ClosedRange<UInt32> = 32...126
    private static let codeB = 100
    private static let startB = 104
    private static let startC = 105
    private static let stop = 106

    /// Ширины штрихов и пробелов символа, начиная со штриха; индекс — значение символа.
    private static let patterns: [String] = [
        "212222", "222122", "222221", "121223", "121322", "131222", "122213", "122312",
        "132212", "221213", "221312", "231212", "112232", "122132", "122231", "113222",
        "123122", "123221", "223211", "221132", "221231", "213212", "223112", "312131",
        "311222", "321122", "321221", "312212", "322112", "322211", "212123", "212321",
        "232121", "111323", "131123", "131321", "112313", "132113", "132311", "211313",
        "231113", "231311", "112133", "112331", "132131", "113123", "113321", "133121",
        "313121", "211331", "231131", "213113", "213311", "213131", "311123", "311321",
        "331121", "312113", "312311", "332111", "314111", "221411", "431111", "111224",
        "111422", "121124", "121421", "141122", "141221", "112214", "112412", "122114",
        "122411", "142112", "142211", "241211", "221114", "413111", "241112", "134111",
        "111242", "121142", "121241", "114212", "124112", "124211", "411212", "421112",
        "421211", "212141", "214121", "412121", "111143", "111341", "131141", "114113",
        "114311", "411113", "411311", "113141", "114131", "311141", "411131", "211412",
        "211214", "211232", "2331112"
    ]
}
