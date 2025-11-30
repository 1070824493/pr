//
//  PRRequestHandlerSignUtils.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
public class PRRequestHandlerSignUtils {
    
    private static var privateKey = ""
    private static var rk1 = ""
    private static var rk2 = ""
    private static var rk3 = ""
    private static var prefixKey = ""
    
    private static var cachePrivateKey = ""
    private static var cacheRandomKey = ""
    
    public static func registerKeys(
        privateKey: String,
        rk1: String,
        rk2: String,
        rk3: String,
        prefixKey: String
    ) {
        self.privateKey = privateKey
        self.rk1 = rk1
        self.rk2 = rk2
        self.rk3 = rk3
        self.prefixKey = prefixKey
    }
    
    static func getRandomKey() -> String {
        if privateKey == cachePrivateKey && !cacheRandomKey.isEmpty {
            return cacheRandomKey
        }
        
        let md51 = String((privateKey + rk1).md5Value.prefix(5))
        var md52 = (privateKey + rk2).md5Value
        md52 = String(md52.suffix(5))
        
        let randomKey = md51 + rk3 + md52
        cacheRandomKey = randomKey
        cachePrivateKey = privateKey
        return randomKey
    }
    
    static func signVerify(signParam: [String: Any], randomKey: String) -> String {
        let keys = signParam.keys.sorted()
        var signStr = keys.map {
            let key = "\($0)"
            var value = "\(signParam[$0]!)"
            value = value.removingPercentEncoding ?? value
            return "\(key)=\(value)"
        }.joined()
        signStr = "\(prefixKey)[\(randomKey.md5Value)]@\(signStr.base64Value)"
        let signHash = signStr.md5Value
        return signHash
    }
    
}
