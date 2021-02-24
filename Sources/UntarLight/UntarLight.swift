
import Foundation

enum Entry: Comparable {
    case file(path: String, offset: Int, length: Int)
    case directory(path: String)
    case symbolicLink(name: String, path: String)
    case zeroBlock
    
    var key: String {
        switch self {
        case .file(let path, _, _):
            return path
        case .directory(let path):
            return path
        case .symbolicLink(let name, _):
            return name
        case .zeroBlock:
            return "_"
        }
    }
}

enum TypeFlag: String {
    
    case regular = "0"               // regular file
    case aRegular = "\\0"            // regular file
    case link = "1"                  // link
    case symbolicLink = "2"          // reserved
    case characterDeviceNode = "3"   // character special
    case blockDevice = "4"           // block
    case directory = "5"             // directory
    case fifo = "6"                  // FIFO
    case cont = "7"                  // reserved
    case extendedHeader = "x"        // Extended header referring to the next file in the archive
    case extendedGlobalHeader = "g"  // Global extended header
    case gnuLongName = "L"           // Next file has a long name
    case gnuLongLink = "K"           // Next file symlinks to a file w/ a long name
    case gnuSparse = "S"             // sparse file
    case unknown = "Unknown"         // unknown error
    
    init(_ value: UInt8) {
        switch value {
        case UInt8(ascii: "0"):
            self = .regular; break
        case UInt8(ascii: "\0"):
            self = .aRegular; break
        case UInt8(ascii: "1"):
            self = .link; break
        case UInt8(ascii: "2"):
            self = .symbolicLink; break
        case UInt8(ascii: "3"):
            self = .characterDeviceNode; break
        case UInt8(ascii: "4"):
            self = .blockDevice; break
        case UInt8(ascii: "5"):
            self = .directory; break
        case UInt8(ascii: "6"):
            self = .fifo; break
        case UInt8(ascii: "7"):
            self = .cont; break
        case UInt8(ascii: "x"):
            self = .extendedHeader; break
        case UInt8(ascii: "g"):
            self = .extendedHeader; break
        default:
            self = .unknown
        }
    }
}

struct Header: CustomStringConvertible {
    let name: String
    let attribute: String
    let userId: String
    let groupId: String
    let length: Int
    let updateDate: Date
    let checkSum: Int
    let typeFlag: TypeFlag
    let linkName: String
    let magic: String
    let userName: String
    let groupName: String
    let major: String
    let minor: String
    let lastAccessDate: Date
    let createDate: Date
    
    var description: String {
        return """
        name = \(name)
        attribute = \(attribute)
        userId = \(userId)
        groupId = \(groupId)
        length = \(length)
        updateDate = \(updateDate)
        checkSum = \(checkSum)
        typeFlag = \(typeFlag)
        linkName = \(linkName)
        magic = \(magic)
        userName = \(userName)
        groupName = \(groupName)
        major = \(major)
        minor = \(minor)
        lastAccessTime = \(lastAccessDate)
        createTime = \(createDate)
        """
    }
}

public enum UntarLightError: Error {
    case headerCheckSumError
    case cannotLoadBlock
    case unknownError
    case pointorHandlingError
    case decodeStringError
    case endOfFile
}

private let extendedNameBlockExtractor: NSRegularExpression = {
    do {
        return try NSRegularExpression(pattern: "(.+?)=(.+)", options: .caseInsensitive)
    } catch {
        fatalError("\(error)")
    }
}()

public extension String {
    var utf16Range: NSRange {
        return NSRange(location: 0, length: self.utf16.count)
    }
}

func traceLongName(data: Data, offset: Int, length: Int) throws -> [String: String] {
    let header = offset
    
    let info = try data.withUnsafeBytes { rawBufferPointer -> [String] in
        guard let rawPtr = rawBufferPointer.baseAddress else { throw UntarLightError.pointorHandlingError }
        var bytes: [UInt8] = (header..<header + length).map { (i: Int) -> UInt8 in
           return rawPtr.advanced(by: Int(i)).load(as: UInt8.self)
        }
        
        var result: [String] = []
        
        while bytes.count > 0 {
            
            guard let spaceIndex = bytes.firstIndex(of: 32) else { throw UntarLightError.unknownError }
            
            let lengthBytes = Array(bytes.prefix(spaceIndex))

            guard let lengthString = String(bytes: lengthBytes, encoding: .utf8) else { throw UntarLightError.unknownError }

            guard let length = Int(lengthString) else { throw UntarLightError.unknownError }

            let nameBytes = Array(bytes.prefix(length).suffix(from: spaceIndex+1))
            
            guard let nameString = String(bytes: nameBytes, encoding: .utf8) else { throw UntarLightError.unknownError }
            
            result.append(nameString)
            
            if bytes.count >= length {
                bytes = Array(bytes.suffix(from: length))
            } else {
                break
            }
        }
        return result
    }
    
    return info.reduce([:] as [String: String], { (dict, string) -> [String: String] in
        
        var temp = dict
        
        if let match = extendedNameBlockExtractor.firstMatch(in: string, options: [], range: string.utf16Range) {
            let key = (string as NSString).substring(with: match.range(at: 1))
            let value = (string as NSString).substring(with: match.range(at: 2))
            temp[key] = value
        }
        
        return temp
    })
}

func bytesToUInt8Array(pointer: UnsafeRawPointer, start: Int, length: Int) -> [UInt8] {
    return (start..<start+length).map { (i: Int) -> UInt8 in
       return pointer.advanced(by: Int(i)).load(as: UInt8.self)
    }
}

func stringExtract(pointer: UnsafeRawPointer, start: Int, length: Int) throws -> String {
    let bytes = bytesToUInt8Array(pointer: pointer, start: start, length: length)
    if let index = bytes.firstIndex(of: 0) {
        let p = Array(bytes.prefix(index))
        guard let string = String(bytes: p, encoding: .utf8) else { throw UntarLightError.decodeStringError }
        return string
    } else {
        guard let string = String(bytes: bytes, encoding: .utf8) else { throw UntarLightError.decodeStringError }
        return string
    }
}

extension String {
    func dateAsTarFormat() -> Date {
        if self.utf16.count > 1 {
            let temp = String(self.prefix(self.utf16.count - 1))
            let updateDateTimeIntervalSince1970 = Double(strtoul(temp, nil, 8))
            return Date(timeIntervalSince1970: updateDateTimeIntervalSince1970)
        } else {
            return Date(timeIntervalSince1970: 0)
        }
    }
}

func padding(length: Int) -> Int {
    let padding = (length % 512 > 0 ? (512 - length % 512) : 0)
    return padding
}

extension FileHandle {
    func forward(_ size: Int) {
        let position = self.offsetInFile
        self.seek(toFileOffset: position + UInt64(size))
    }
}

func extractFile(fh: FileHandle, entry: Entry) throws -> Data {
    switch entry {
    case .file(let _, let offset, let length):
        print(offset)
        print(length)
        fh.seek(toFileOffset: UInt64(offset))
        let data = fh.readData(ofLength: length)
        guard data.count == length else { throw UntarLightError.unknownError}
        return data
    default:
        throw UntarLightError.unknownError
    }
}

func extractTarEntry(fh: FileHandle) throws -> [Entry] {
    
    var array: [Entry] = []
    
    do {
        var extenededNameDict: [String: String]? = nil
        
        while true {
            let data = fh.readData(ofLength: 512)
            
            if data.count == 0 { throw UntarLightError.endOfFile }
            guard data.count == 512 else { throw UntarLightError.unknownError }
            
            let checkSum = try data.checkSum()
            
            guard checkSum != 256 else {
                // zero block
                array.append(.zeroBlock)
                continue
            }
            let header = try data.loadHeader()
            
            guard header.checkSum == checkSum else { throw UntarLightError.headerCheckSumError }
            
            switch header.typeFlag {
            case .directory:
                
                if let dict = extenededNameDict, let name = dict["path"] {
                    extenededNameDict = nil
                    array.append(Entry.directory(path: name))
                } else {
                    array.append(Entry.directory(path: header.name))
                }
            case .extendedHeader:
                let subdata = fh.readData(ofLength: header.length)
                
                if subdata.count == 0 { throw UntarLightError.endOfFile }
                guard subdata.count == header.length else { throw UntarLightError.cannotLoadBlock }
                
                extenededNameDict = try subdata.loadLongName()
                
                fh.forward(padding(length: header.length))
            case .symbolicLink:
                if let dict = extenededNameDict, let linkpath = dict["linkpath"], let path = dict["path"] {
                    extenededNameDict = nil
                    array.append(Entry.symbolicLink(name: path, path: linkpath))
                } else if let dict = extenededNameDict, let linkpath = dict["linkpath"] {
                    extenededNameDict = nil
                    array.append(Entry.symbolicLink(name: header.name, path: linkpath))
                } else {
                    array.append(Entry.symbolicLink(name: header.name, path: header.linkName))
                }
            case .aRegular, .regular:
                
                let paddingLength = padding(length: header.length)
                
                let fileOffset = Int(fh.offsetInFile)
                let fileLength = header.length
                
                fh.forward(paddingLength + header.length)
                
                if let dict = extenededNameDict, let name = dict["path"] {
                    
                    extenededNameDict = nil
                    let e = Entry.file(path: name, offset: fileOffset, length: fileLength)
                    array.append(e)
                } else {
                    let e = Entry.file(path: header.name, offset: fileOffset, length: fileLength)
                    array.append(e)
                }
            default:
                let paddingLength = padding(length: header.length)
                fh.forward(paddingLength + header.length)
            }
            
        }
    } catch UntarLightError.endOfFile {
        
    } catch {
        throw error
    }
    
    guard array.count >= 2 else { throw UntarLightError.unknownError }
    guard array[array.count - 2] == .zeroBlock else { throw UntarLightError.unknownError }
    guard array[array.count - 1] == .zeroBlock else { throw UntarLightError.unknownError }
    
    array.remove(at: array.count - 1)
    array.remove(at: array.count - 1)
    
    return array
}

extension Data {
    
    func checkSum() throws -> Int {
        return try self.withUnsafeBytes { rawBufferPointer -> Int in
            guard let rawPtr = rawBufferPointer.baseAddress else { throw UntarLightError.pointorHandlingError }
            var bytes = (0..<self.count).map { (i: Int) -> UInt in
               return UInt(rawPtr.advanced(by: Int(i)).load(as: UInt8.self))
            }
            for i in 0..<8 {
                bytes[i + 148] = 32 // this is blank
            }
            return bytes.reduce(Int(0)) { (sum, value) -> Int in
                return sum + Int(value)
            }
        }
        
    }
    
    func loadLongName() throws -> [String: String] {
        
        let info = try self.withUnsafeBytes { rawBufferPointer -> [String] in
            guard let rawPtr = rawBufferPointer.baseAddress else { throw UntarLightError.pointorHandlingError }
            var bytes: [UInt8] = (0..<self.count).map { (i: Int) -> UInt8 in
               return rawPtr.advanced(by: Int(i)).load(as: UInt8.self)
            }
            
            var result: [String] = []
            
            while bytes.count > 0 {
                
                guard let spaceIndex = bytes.firstIndex(of: 32) else { throw UntarLightError.unknownError }
                
                let lengthBytes = Array(bytes.prefix(spaceIndex))

                guard let lengthString = String(bytes: lengthBytes, encoding: .utf8) else { throw UntarLightError.unknownError }

                guard let length = Int(lengthString) else { throw UntarLightError.unknownError }
                
                let nameBytes = Array(bytes.prefix(length).suffix(from: spaceIndex+1))
                
                guard let nameString = String(bytes: nameBytes, encoding: .utf8) else { throw UntarLightError.unknownError }
                
                result.append(nameString)
                
                if bytes.count >= length {
                    bytes = Array(bytes.suffix(from: length))
                } else {
                    break
                }
            }
            return result
        }
        
        return info.reduce([:] as [String: String], { (dict, string) -> [String: String] in
            
            var temp = dict
            
            if let match = extendedNameBlockExtractor.firstMatch(in: string, options: [], range: string.utf16Range) {
                let key = (string as NSString).substring(with: match.range(at: 1))
                let value = (string as NSString).substring(with: match.range(at: 2))
                temp[key] = value
            }
            
            return temp
        })
    }
    
    func loadHeader() throws -> Header {
        
        return try self.withUnsafeBytes { rawBufferPointer -> Header in
            guard let rawPtr = rawBufferPointer.baseAddress else {
                throw UntarLightError.pointorHandlingError
            }

            let name = { () -> String in
            do {
                // "tar" sometimes cuts the data in the middle of a string of UTF-8 character bytes when it is a longer name more than 100 bytes.
                // Therefore, String sometimes can not decode bytes into String.
                // In such case, its following block has the right name.
                return try stringExtract(pointer: rawPtr, start: 0, length: 100)
            } catch {
                return "wrong name"
            }}()
            
            let attribute = try stringExtract(pointer: rawPtr, start: 100, length: 8)
            let userId = try stringExtract(pointer: rawPtr, start: 108, length: 8)
            let groupId = try stringExtract(pointer: rawPtr, start: 116, length: 8)

            
            let sizeString = try stringExtract(pointer: rawPtr, start: 124, length: 12)
            let size = Int(strtoul(sizeString, nil, 8))
            
            let updateDateString = try stringExtract(pointer: rawPtr, start: 136, length: 12)
            let updateDate = updateDateString.dateAsTarFormat()
            
            let checkSumString = try stringExtract(pointer: rawPtr, start: 148, length: 8)
            let checkSum = Int((strtoul(checkSumString, nil, 8)))
            
            let typeFlagBytes = bytesToUInt8Array(pointer: rawPtr, start: 156, length: 1)
            let typeFlag = TypeFlag(typeFlagBytes[0])

            let linkName = try stringExtract(pointer: rawPtr, start: 157, length: 100)
            let magic = try stringExtract(pointer: rawPtr, start: 257, length: 8)

            let userName = try stringExtract(pointer: rawPtr, start: 265, length: 32)
            let groupName = try stringExtract(pointer: rawPtr, start: 297, length: 32)

            let major = try stringExtract(pointer: rawPtr, start: 329, length: 8)
            let minor = try stringExtract(pointer: rawPtr, start: 337, length: 8)

            let lastAccessDateString = try stringExtract(pointer: rawPtr, start: 345, length: 12)
            let lastAccessDate = lastAccessDateString.dateAsTarFormat()
            
            let createDateString = try stringExtract(pointer: rawPtr, start: 357, length: 12)
            let createDate = createDateString.dateAsTarFormat()

            return Header(name: name, attribute: attribute, userId: userId, groupId: groupId, length: size, updateDate: updateDate, checkSum: checkSum, typeFlag: typeFlag, linkName: linkName, magic: magic, userName: userName, groupName: groupName, major: major, minor: minor, lastAccessDate: lastAccessDate, createDate: createDate)
        }
    }
}
