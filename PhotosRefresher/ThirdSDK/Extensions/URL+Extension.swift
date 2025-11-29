//
//  URL+Extension.swift
//  OverseasSwiftExtensions
//

public extension URL {
    
    func pathWithoutSuffix() -> String {
        var curPath = path
        if curPath.isEmpty {
            return curPath
        }
        
        if curPath.hasSuffix("/") {
            curPath.removeLast()
        }
        
        return curPath
    }
    
}


public extension URLRequest {
    
    func queryItems() -> [String: Any]? {
        guard let url = self.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        var queryDict = [String: String]()
        for queryItem in queryItems {
            queryDict[queryItem.name] = queryItem.value
        }
        
        return queryDict
    }
    
    func percentEncodedQueryItems() -> [String: Any]? {
        guard let url = self.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.percentEncodedQueryItems else {
            return nil
        }
        
        var queryDict = [String: String]()
        for queryItem in queryItems {
            queryDict[queryItem.name] = queryItem.value
        }
        
        return queryDict
    }
    
}
