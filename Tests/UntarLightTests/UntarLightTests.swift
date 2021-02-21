import XCTest
@testable import UntarLight

import Foundation

final class UntarLightTests: XCTestCase {
    
    func testFileHandle() {
        
        do {
            guard let path = Bundle.module.path(forResource: "list.json", ofType: "") else { XCTFail("Can not open resource json file."); return }
            let fileURL = NSURL.fileURL(withPath: path)
            let data = try Data(contentsOf: fileURL)
            guard let test_json_files = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String] else { XCTFail("Can not open resource json file."); return }
            
            try test_json_files.forEach {
                
                print($0)
                
                guard let path = Bundle.module.path(forResource: $0, ofType: "") else { XCTFail("Can not open resource json file."); return }
                let fileURL = NSURL.fileURL(withPath: path)
                let data = try Data(contentsOf: fileURL)
                guard let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else { XCTFail("Can not open resource json file."); return }
                
                guard let fileName = json["name"] as? String else { XCTFail("Can not open resource json file."); return }
                guard var test_entries = json["entries"] as? [[String: String]] else { XCTFail("Can not open resource json file."); return }
                
                
                guard let tarPath = Bundle.module.path(forResource: fileName, ofType: "") else { XCTFail("Can not open resource json file."); return }
                let tarURL = NSURL.fileURL(withPath: tarPath)
                let fh = try FileHandle(forReadingFrom: tarURL)
                
                let entries = try extractTarEntry(fh: fh)
                
                entries.forEach({
                    switch $0 {
                    case .directory(let path):
                        if let index = test_entries.firstIndex(where: { (dict: [String: String]) -> Bool in
                            guard let type = dict["type"] else { return false }
                            guard let trueName = dict["path"] else { return false }
                            guard type == "directory" else { return false }
                            return path == (trueName + "/")
                        }) {
                            test_entries.remove(at: index)
                        }
                    case .file(let path, _, _):
                        if let index = test_entries.firstIndex(where: { (dict: [String: String]) -> Bool in
                            guard let type = dict["type"] else { return false }
                            guard let trueName = dict["path"] else { return false }
                            guard type == "file" else { return false }
                            return trueName == (path)
                        }) {
                            test_entries.remove(at: index)
                        }
                    case .symbolicLink(let name, let path):
                        if let index = test_entries.firstIndex(where: { (dict: [String: String]) -> Bool in
                            guard let type = dict["type"] else { return false }
                            guard let trueName = dict["path"] else { return false }
                            guard let trueLink = dict["link"] else { return false }
                            guard type == "symboliclink" else { return false }
                            return name == (trueName) && (path == trueLink)
                        }) {
                            test_entries.remove(at: index)
                        }
                    default:
                        XCTFail("Unexpected entry shows")
                    }
                })
                if test_entries.count > 0 {
                    print(entries)
                    print(test_entries)
                }
                XCTAssert(test_entries.count == 0, "\(fileName) is failed.")
                print("\(fileName) is OK.")
            }
        } catch {
            print(error)
            XCTFail(error.localizedDescription)
        }
    }

    static var allTests = [
        ("testExample", testFileHandle),
    ]
}
