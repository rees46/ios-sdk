import Foundation

public enum NetworkRadioType: CustomStringConvertible {
    case notdeterminedcellular
    case _2G
    case _3G
    case _4G
    case _5G
    
    public var description: String {
        switch self {
        case .notdeterminedcellular:
            return "NotDeterminedCellular"
        case ._2G:
            return "2G"
        case ._3G:
            return "3G"
        case ._4G:
            return "4G"
        case ._5G:
            return "5G"
        }
    }
}
