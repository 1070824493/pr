//
//  Data+Extension.swift
//  OverseasSwiftExtensions
//

//


import Foundation
import CommonCrypto

public extension Data {
    
    var md5Value: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        let hash = self.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash: [UInt8] = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(self.count), &hash)
            return hash
        }
        return (0..<length).map { String(format: "%02x", hash[$0]) }.joined()
    }
    
}
