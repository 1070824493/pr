//
//  PRRequestHandlerManager.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Alamofire

public typealias RetryDelayPolicy = (_ attempt: Int) -> TimeInterval

public enum RetryPolicyFactory {
    /// 指数退避 + full jitter
    public static func PRExponentialFullJitter(
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffFactor: Double = 2.0
    ) -> RetryDelayPolicy {
        return { attempt in
            let baseDelay = initialDelay * pow(backoffFactor, Double(attempt - 1))
            let capped = min(maxDelay, baseDelay)
            return Double.random(in: 0...capped)
        }
    }
    
    /// 指数退避（无 jitter）
    public static func PRExponential(
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffFactor: Double = 2.0
    ) -> RetryDelayPolicy {
        return { attempt in
            let baseDelay = initialDelay * pow(backoffFactor, Double(attempt - 1))
            return min(maxDelay, baseDelay)
        }
    }
    
    /// 固定间隔重试
    public static func fixed(delay: TimeInterval) -> RetryDelayPolicy {
        return { _ in delay }
    }
}


public struct PRBusinessEmptyParameter: CodableWithDefault {
    public static var defaultValue: PRBusinessEmptyParameter {
        return PRBusinessEmptyParameter()
    }
}

public struct PRBusinessEmptyResponse: CodableWithDefault {
    public static var defaultValue: PRBusinessEmptyResponse {
        return PRBusinessEmptyResponse()
    }
}

public protocol PRDynamicCommonParamsProvider {
    static func getDynamicCommonParams() -> [String: Any]
}

public class PRRequestHandlerManager {
    
    public static let shared = PRRequestHandlerManager()
    
    public let session: Session
    public let commonParameterInterceptor: PRCommonParameterInterceptor
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 360
        
        self.commonParameterInterceptor = PRCommonParameterInterceptor()
        self.session = Session(configuration: configuration, interceptor: commonParameterInterceptor)
    }
    
    public func addCommonParameters(_ parameters: [String: Any]) {
        commonParameterInterceptor.addCommonParameters(parameters)
    }
    
    public func addCookies(_ cookies: [HTTPCookie]) {
        commonParameterInterceptor.addCommonCookies(cookies)
    }
    
    public func registerDynamicCommonParamsProvider(provider: PRDynamicCommonParamsProvider.Type) {
        commonParameterInterceptor.registerDynamicCommonParamsProvider(provider: provider)
    }
    
    public func PRrequest<Input: Encodable>(
        url: String,
        method: HTTPMethod,
        parameters: Input? = nil,
        headers: HTTPHeaders? = nil,
        timeout: TimeInterval = 60,
        parameterEncoding: ParameterEncoding = URLEncoding.default,
        maxRetryCount: Int = 0,
        retryPolicy: RetryDelayPolicy = RetryPolicyFactory.PRExponentialFullJitter()
    ) async throws {
        let _: PRCommonResponse<PRBusinessEmptyResponse> = try await PRrequest(url: url, method: method, parameters: parameters, headers: headers, timeout: timeout, parameterEncoding: parameterEncoding, maxRetryCount: maxRetryCount, retryPolicy: retryPolicy)
    }
    
    public func PRrequest<OutputData: DecodableWithDefault>(
        url: String,
        method: HTTPMethod,
        headers: HTTPHeaders? = nil,
        timeout: TimeInterval = 60,
        parameterEncoding: ParameterEncoding = URLEncoding.default,
        maxRetryCount: Int = 0,
        retryPolicy: RetryDelayPolicy = RetryPolicyFactory.PRExponentialFullJitter()
    ) async throws -> PRCommonResponse<OutputData> {
        return try await PRrequest(url: url, method: method, parameters: PRBusinessEmptyParameter(), headers: headers, timeout: timeout, parameterEncoding: parameterEncoding, maxRetryCount: maxRetryCount, retryPolicy: retryPolicy)
    }
    
    public func PRrequest<Input: Encodable, OutputData: DecodableWithDefault>(
        url: String,
        method: HTTPMethod,
        parameters: Input? = nil,
        headers: HTTPHeaders? = nil,
        timeout: TimeInterval = 60,
        parameterEncoding: ParameterEncoding = URLEncoding.default,
        maxRetryCount: Int = 0,
        retryPolicy: RetryDelayPolicy = RetryPolicyFactory.PRExponentialFullJitter()
    ) async throws -> PRCommonResponse<OutputData> {
        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetryCount {
            do {
                let requestUrl = PREnvironmentManager.shared.PRCreateFullRequestUrl(url)
                var urlRequest = try URLRequest(url: requestUrl, method: method, headers: headers)
                urlRequest.timeoutInterval = timeout

                if let parameters = parameters {
                    switch parameterEncoding {
                    case is URLEncoding:
                        urlRequest = try URLEncodedFormParameterEncoder.default.encode(parameters, into: urlRequest)
                    case is JSONEncoding:
                        urlRequest = try JSONParameterEncoder.default.encode(parameters, into: urlRequest)
                    default:
                        print("parameters: \(parameters)")
                    }
                }

                let response = await session
                    .request(urlRequest)
                    .serializingDecodable(PRCommonResponse<OutputData>.self)
                    .response

                if let httpResponse = response.response {
                    let statusCode = httpResponse.statusCode
                    if (400...499).contains(statusCode) {
                        throw NSError(domain: "Client Error", code: statusCode, userInfo: nil)
                    } else if (500...599).contains(statusCode) {
                        throw NSError(domain: "Server Error", code: statusCode, userInfo: nil)
                    }
                }

                switch response.result {
                case .success(let commonResponse):
                    return commonResponse
                case .failure(let error):
                    throw error
                }
            } catch {
                lastError = error
                attempt += 1

                if attempt > maxRetryCount {
                    break
                }

                let delay = retryPolicy(attempt)
                print("Retry attempt \(attempt) after \(delay)s due to error: \(error)")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? URLError(.cannotLoadFromNetwork)
    }

    
    public func PRget<Input: Encodable, OutputData: DecodableWithDefault>(
        url: String,
        parameters: Input? = nil,
        headers: HTTPHeaders? = nil,
        timeout: TimeInterval = 60,
        maxRetryCount: Int = 0,
        retryPolicy: RetryDelayPolicy = RetryPolicyFactory.PRExponentialFullJitter()
    ) async throws -> PRCommonResponse<OutputData> {
        return try await PRrequest(
            url: url,
            method: .get,
            parameters: parameters,
            headers: headers,
            timeout: timeout,
            parameterEncoding: URLEncoding.default,
            maxRetryCount: maxRetryCount,
            retryPolicy: retryPolicy
        )
    }
    
    public func PRpost<Input: Encodable, OutputData: DecodableWithDefault>(
        url: String,
        parameters: Input,
        headers: HTTPHeaders? = nil,
        timeout: TimeInterval = 60,
        parameterEncoding: ParameterEncoding = URLEncoding.default,
        maxRetryCount: Int = 0,
        retryPolicy: RetryDelayPolicy = RetryPolicyFactory.PRExponentialFullJitter()
    ) async throws -> PRCommonResponse<OutputData> {
        return try await PRrequest(
            url: url,
            method: .post,
            parameters: parameters,
            headers: headers,
            timeout: timeout,
            parameterEncoding: parameterEncoding,
            maxRetryCount: maxRetryCount,
            retryPolicy: retryPolicy
        )
    }
    
    public func PRrequestAny(
        url: String,
        method: HTTPMethod,
        parameters: [String: Any]? = nil,
        headers: HTTPHeaders? = nil,
        timeout: TimeInterval = 60,
        parameterEncoding: ParameterEncoding = URLEncoding.default,
        maxRetryCount: Int = 3,
        retryPolicy: RetryDelayPolicy = RetryPolicyFactory.PRExponentialFullJitter()
    ) async throws -> [String: Any] {
        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetryCount {
            do {
                let requestUrl = PREnvironmentManager.shared.PRCreateFullRequestUrl(url)
                var urlRequest = try URLRequest(url: requestUrl, method: method, headers: headers)
                urlRequest.timeoutInterval = timeout

                if let parameters = parameters {
                    switch parameterEncoding {
                    case is URLEncoding:
                        urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
                    case is JSONEncoding:
                        urlRequest = try JSONEncoding.default.encode(urlRequest, with: parameters)
                    default:
                        print("parameters: \(parameters)")
                    }
                }

                let response = await session.request(urlRequest).serializingData().response

                if let httpResponse = response.response {
                    let statusCode = httpResponse.statusCode
                    if (400...499).contains(statusCode) {
                        throw NSError(domain: "Client Error", code: statusCode, userInfo: nil)
                    } else if (500...599).contains(statusCode) {
                        throw NSError(domain: "Server Error", code: statusCode, userInfo: nil)
                    }
                }

                switch response.result {
                case .success(let data):
                    do {
                        let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
                        return dictionary ?? [:]
                    } catch {
                        print("toDictionary：\(error)")
                        throw error
                    }
                case .failure(let error):
                    throw error
                }
            } catch {
                lastError = error
                attempt += 1

                if attempt > maxRetryCount {
                    break
                }

                let delay = retryPolicy(attempt)
                print("Retry attempt \(attempt) after \(delay)s due to error: \(error)")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? URLError(.cannotLoadFromNetwork)
    }
    
}


