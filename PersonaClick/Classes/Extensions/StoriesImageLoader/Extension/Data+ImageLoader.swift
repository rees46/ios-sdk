import Foundation

extension Data {

    enum FileType {
        case png
        case jpeg
        case gif
        case tiff
        case webp
        case Unknown
    }

    internal var fileType: FileType {
        let fileHeader = getFileHeader(capacity: 2)
        switch fileHeader {
        case [0x47, 0x49]:
            return .gif
        case [0xFF, 0xD8]:
            return .jpeg
        case [0x89, 0x50]:
            return .png
        default:
            return .Unknown
        }
    }

    internal func getFileHeader(capacity: Int) -> [UInt8] {

        var pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        
        (self as NSData).getBytes(pointer, length: capacity)

        var header = [UInt8]()
        for _ in 0 ..< capacity {
            header.append(pointer.pointee)
            pointer += 1
        }

        return header
    }

}
