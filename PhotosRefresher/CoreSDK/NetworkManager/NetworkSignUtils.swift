//
//  SignUtils.swift
//



public class NetworkSignUtils {
    
    private static var privateKey = ""
    private static var randomKey1 = ""
    private static var randomKey2 = ""
    private static var randomKey3 = ""
    private static var prefixKey = ""
    
    private static var cachePrivateKey = ""
    private static var cacheRandomKey = ""
    
    public static func registerKeys(
        privateKey: String,
        randomKey1: String,
        randomKey2: String,
        randomKey3: String,
        prefixKey: String
    ) {
        self.privateKey = privateKey
        self.randomKey1 = randomKey1
        self.randomKey2 = randomKey2
        self.randomKey3 = randomKey3
        self.prefixKey = prefixKey
    }
    
    static func getRandomKey() -> String {
        if privateKey == cachePrivateKey && !cacheRandomKey.isEmpty {
            return cacheRandomKey
        }
        
        let md51 = String((privateKey + randomKey1).md5Value.prefix(5))
        var md52 = (privateKey + randomKey2).md5Value
        md52 = String(md52.suffix(5))
        
        let randomKey = md51 + randomKey3 + md52
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
