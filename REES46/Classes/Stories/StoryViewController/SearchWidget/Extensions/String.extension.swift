import Foundation

extension String {
    func formattedCurrency(withSymbol symbol: String) -> String {
        return "\(symbol)\(self)"
    }
}
