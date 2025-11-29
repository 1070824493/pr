//
//  PRRequestHandlerInterceptor.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Alamofire


public class PRCommonParameterInterceptor: RequestInterceptor, @unchecked Sendable {
    
    private var commonParameters: [String: Any] = [:]
    private var commonCookies: [HTTPCookie] = []
    private var dynamicCommonParamsProvider: PRDynamicCommonParamsProvider.Type?
    
    func addCommonParameters(_ parameters: [String: Any]) {
        for (key, value) in parameters {
            self.commonParameters[key] = value
        }
    }
    
    func addCommonCookies(_ cookies: [HTTPCookie]) {
        for (cookie) in cookies {
            self.commonCookies.append(cookie)
        }
    }
    
    func registerDynamicCommonParamsProvider(provider: PRDynamicCommonParamsProvider.Type) {
        dynamicCommonParamsProvider = provider
    }
    
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest
        
        do {
            let randomKey = PRRequestHandlerSignUtils.getRandomKey()
            let dynamicCommonParams = dynamicCommonParamsProvider?.getDynamicCommonParams()
            switch urlRequest.method {
            case .get, .head, .connect, .options, .trace:
                var addParameters = [String: Any]()
                addParameters["_t_"] = String(Int(Date().timeIntervalSince1970))
                addParameters.merge(commonParameters) { (current, new) in current }
                if let dynamicCommonParams = dynamicCommonParams {
                    addParameters.merge(dynamicCommonParams) { (current, new) in new }
                }
                
                var signPercentEncodedQueryItems = urlRequest.percentEncodedQueryItems() ?? [:]
                signPercentEncodedQueryItems.merge(addParameters) { (current, new) in current }
                let sign = PRRequestHandlerSignUtils.signVerify(signParam: signPercentEncodedQueryItems, randomKey: randomKey)
                
                addParameters["sign"] = sign
                urlRequest = try URLEncoding.default.encode(urlRequest, with: addParameters)
            default:
                let contentType = urlRequest.value(forHTTPHeaderField: "Content-Type") ?? ""
                if contentType.contains("application/json") {
                    let bodyData = urlRequest.httpBody ?? Data()
                    var bodyDict = try JSONSerialization.jsonObject(with: bodyData, options: .allowFragments) as? [String: Any] ?? [:]
                    bodyDict.merge(commonParameters) { (current, new) in current }
                    if let dynamicCommonParams = dynamicCommonParams {
                        bodyDict.merge(dynamicCommonParams) { (current, new) in new }
                    }
                    bodyDict["_t_"] = String(Int(Date().timeIntervalSince1970))
                    
                    let sign = PRRequestHandlerSignUtils.signVerify(signParam: bodyDict, randomKey: randomKey)
                    bodyDict["sign"] = sign
                    urlRequest = try JSONEncoding.default.encode(urlRequest, with: bodyDict)
                } else if contentType.contains("application/x-www-form-urlencoded") {
                    var addParameters = [String: Any]()
                    addParameters.merge(commonParameters) { (current, new) in current }
                    if let dynamicCommonParams = dynamicCommonParams {
                        addParameters.merge(dynamicCommonParams) { (current, new) in new }
                    }
                    
                    let bodyString = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? ""
                    var bodyDict = URLComponents()
                    bodyDict.percentEncodedQuery = bodyString
                    bodyDict.queryItems?.forEach { queryItem in
                        addParameters[queryItem.name] = queryItem.value
                    }
                    addParameters["_t_"] = String(Int(Date().timeIntervalSince1970))
                    
                    let sign = PRRequestHandlerSignUtils.signVerify(signParam: addParameters, randomKey: randomKey)
                    addParameters["sign"] = sign
                    urlRequest = try URLEncoding.default.encode(urlRequest, with: addParameters)
                }
            }
        } catch {
            completion(.failure(error))
            return
        }
        
        if !commonCookies.isEmpty {
            var cookieHeader = commonCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            if PREnvironmentManager.shared.isTips() {
                cookieHeader += "; __tips__=1"
            }
            urlRequest.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        } else {
            if PREnvironmentManager.shared.isTips() {
                urlRequest.setValue("__tips__=1", forHTTPHeaderField: "Cookie")
            }
        }
        
        completion(.success(urlRequest))
    }
    
    public func getCommonParameters() -> [String: Any] {
        return self.commonParameters
    }
    
    public func getDynamicCommonParams() -> [String: Any]? {
        return self.dynamicCommonParamsProvider?.getDynamicCommonParams()
    }
    
    public func getCommonCookies() -> [HTTPCookie] {
        return self.commonCookies
    }
    
}
