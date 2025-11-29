//
//  NetworkManager+File.swift
//

//

import Foundation
import Alamofire

public enum TransferState<T> {
    case inProgress(Double)      // 传输中，包含进度 (0~1)
    case completed(T?)           // 传输完成，包含结果（如`Data`或`模型`）
    case failed(Error)           // 传输失败，包含错误信息
}

public extension PRRequestHandlerManager {
    
    // 上传单个文件（带表单参数）
    func PRUploadFile<Output: Decodable>(
        to url: String,
        file: (url: URL, parameterName: String),
        parameters: [String: Any]? = nil,
        headers: HTTPHeaders? = nil,
        responseType: Output.Type
    ) -> AsyncStream<TransferState<PRCommonResponse<Output>>> {
        return PRUpload(multipartFormDataBlock: { multipartFormData in
            multipartFormData.append(file.url, withName: file.parameterName)
        }, to: url, parameters: parameters, headers: headers, responseType: responseType)
    }
    
    func PRUploadFile<Output: Decodable>(
        to url: String,
        file: (data: Data, parameterName: String, fileName: String, mimeType: String?),
        parameters: [String: Any]? = nil,
        headers: HTTPHeaders? = nil,
        responseType: Output.Type
    ) -> AsyncStream<TransferState<PRCommonResponse<Output>>> {
        return PRUpload(multipartFormDataBlock: { multipartFormData in
            multipartFormData.append(file.data, withName: file.parameterName, fileName: file.fileName, mimeType: file.mimeType)
        }, to: url, parameters: parameters, headers: headers, responseType: responseType)
    }
    
    // 上传多个文件（带表单参数）
    func PRUploadMultiFiles<Output: Decodable>(
        to url: String,
        files: [(url: URL, parameterName: String)],
        parameters: [String: Any]? = nil,
        headers: HTTPHeaders? = nil,
        responseType: Output.Type
    ) -> AsyncStream<TransferState<PRCommonResponse<Output>>> {
        return PRUpload(multipartFormDataBlock: { multipartFormData in
            for file in files {
                multipartFormData.append(file.url, withName: file.parameterName)
            }
        }, to: url, parameters: parameters, headers: headers, responseType: responseType)
    }
    
    func PRUploadMultiFiles<Output: Decodable>(
        to url: String,
        files: [(data: Data, parameterName: String, fileName: String, mimeType: String?)],
        parameters: [String: Any]? = nil,
        headers: HTTPHeaders? = nil,
        responseType: Output.Type
    ) -> AsyncStream<TransferState<PRCommonResponse<Output>>> {
        return PRUpload(multipartFormDataBlock: { multipartFormData in
            for file in files {
                multipartFormData.append(file.data, withName: file.parameterName, fileName: file.fileName, mimeType: file.mimeType)
            }
        }, to: url, parameters: parameters, headers: headers, responseType: responseType)
    }
    
    private func PRUpload<Output: Decodable>(
        multipartFormDataBlock: @escaping (MultipartFormData) -> Void,
        to url: String,
        parameters: [String: Any]? = nil,
        headers: HTTPHeaders? = nil,
        responseType: Output.Type
    ) -> AsyncStream<TransferState<PRCommonResponse<Output>>> {
        return AsyncStream { continuation in
            let requestUrl = PREnvironmentManager.shared.PRCreateFullRequestUrl(url)
            let uploadRequest = session.upload(multipartFormData: { multipartFormData in
                multipartFormDataBlock(multipartFormData)
                
                var addParameters = [String: Any]()
                if let parameters = parameters {
                    addParameters.merge(parameters) { (current, new) in current }
                }
                
                let commonParameters = self.commonParameterInterceptor.getCommonParameters()
                addParameters.merge(commonParameters) { (current, new) in current }
                
                if let dynamicCommonParameters = self.commonParameterInterceptor.getDynamicCommonParams() {
                    addParameters.merge(dynamicCommonParameters) { (current, new) in current }
                }
                
                addParameters["_t_"] = String(Int(Date().timeIntervalSince1970))
                let randomKey = PRRequestHandlerSignUtils.getRandomKey()
                let sign = PRRequestHandlerSignUtils.signVerify(signParam: addParameters, randomKey: randomKey)
                addParameters["sign"] = sign
                
                for (key, value) in addParameters {
                    if let valueData = "\(value)".data(using: .utf8) {
                        multipartFormData.append(valueData, withName: key)
                    }
                }
            }, to: requestUrl, headers: headers)
            
            uploadRequest.uploadProgress { progress in
                continuation.yield(.inProgress(progress.fractionCompleted))
            }
            
            uploadRequest.responseDecodable(of: PRCommonResponse<Output>.self) { (response: DataResponse<PRCommonResponse<Output>, AFError>) in
                switch response.result {
                case .success(let model):
                    continuation.yield(.completed(model))
                case .failure(let error):
                    continuation.yield(.failed(error))
                }
                continuation.finish()
            }
        }
    }
    
    // 下载文件到本地
    func PRDownloadFile(
        from url: String,
        to destinationURL: URL? = nil,
        headers: HTTPHeaders? = nil,
        timeout: TimeInterval = 60,
        retryCount: Int = 0,
        retryPolicy: @escaping RetryDelayPolicy = RetryPolicyFactory.fixed(delay: 0)
    ) -> AsyncStream<TransferState<URL?>> {
        return AsyncStream { continuation in
            Task {
                var attempt = 1
                
                while attempt <= retryCount + 1 {
                    var hasResume = false
                    let result = await withCheckedContinuation { (continuationChecked: CheckedContinuation<Result<URL?, AFError>, Never>) in
                        
                        let destination: DownloadRequest.Destination = { _, _ in
                            (
                                destinationURL ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
                                [.removePreviousFile, .createIntermediateDirectories]
                            )
                        }
                        
                        session.download(
                            url,
                            headers: headers,
                            requestModifier: { $0.timeoutInterval = timeout },
                            to: destination
                        )
                        .downloadProgress { progress in
                            continuation.yield(.inProgress(progress.fractionCompleted))
                        }
                        .response { response in
                            if !hasResume {
                                hasResume = true
                                continuationChecked.resume(returning: response.result)
                            }
                        }
                    }
                    
                    switch result {
                    case .success(let fileURL):
                        continuation.yield(.completed(fileURL))
                        continuation.finish()
                        return
                        
                    case .failure(let error):
                        if attempt > retryCount {
                            continuation.yield(.failed(error))
                            continuation.finish()
                            return
                        } else {
                            let delay = retryPolicy(attempt)
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            attempt += 1
                        }
                    }
                }
            }
        }
    }
    
    // 下载文件数据（不存本地）
    func PRDownloadData(
        from url: String,
        headers: HTTPHeaders? = nil,
        timeout: TimeInterval = 60,
        retryCount: Int = 0,
        retryPolicy: @escaping RetryDelayPolicy = RetryPolicyFactory.fixed(delay: 0)
    ) -> AsyncStream<TransferState<Data>> {
        return AsyncStream { continuation in
            Task {
                var attempt = 1
                
                while attempt <= retryCount + 1 {
                    var hasResume = false
                    
                    var urlRequest = try! URLRequest(url: url, method: .get, headers: headers)
                    urlRequest.timeoutInterval = timeout
                    
                    let result: Result<Data, AFError> = await withCheckedContinuation { checkedContinuation in
                        session.request(urlRequest)
                            .downloadProgress { progress in
                                continuation.yield(.inProgress(progress.fractionCompleted))
                            }
                            .responseData { response in
                                if !hasResume {
                                    hasResume = true
                                    checkedContinuation.resume(returning: response.result)
                                }
                            }
                    }
                    
                    switch result {
                    case .success(let data):
                        continuation.yield(.completed(data))
                        continuation.finish()
                        return
                        
                    case .failure(let error):
                        if attempt > retryCount {
                            continuation.yield(.failed(error))
                            continuation.finish()
                            return
                        } else {
                            let delay = retryPolicy(attempt)
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            attempt += 1
                        }
                    }
                }
            }
        }
    }
    
}
