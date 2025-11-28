//
//  String+Extension.swift
//  OverseasSwiftExtensions
//

import Foundation
import CommonCrypto

public extension String {
    
    func substring(from: Int, to: Int) -> String? {
        if to >= self.count || to < 0 || from >= self.count || from < 0 || from >= to {
            return nil
        }
        let start = self.index(self.startIndex, offsetBy: from)
        let end = self.index(self.startIndex, offsetBy: to)
        return String(self[start ..< end])
    }
    
    func substring(from: Int, length: Int) -> String? {
        if from >= self.count || from < 0 || length > self.count || length < 0 || from + length > self.count {
            return nil
        }
        let start = self.index(self.startIndex, offsetBy: from)
        let end = self.index(start, offsetBy: length)
        return String(self[start ..< end])
    }
    
    func withoutSuffix() -> String {
        var curPath = self
        if curPath.isEmpty {
            return curPath
        }
        
        if curPath.hasSuffix("/") {
            curPath.removeLast()
        }
        
        return curPath
    }
    
    var md5Value: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        
        guard let data = data(using: String.Encoding.utf8) else { return self }
        
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash: [UInt8] = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        
        return (0..<length).map { String(format: "%02x", hash[$0]) }.joined()
    }
    
    var base64Value: String {
        guard let data = self.data(using: .utf8) else {
            return self
        }

        return data.base64EncodedString()
    }

    
}
