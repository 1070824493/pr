//
//  PRRequestHandlerNetworkManager+Stream.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Alamofire

public enum StreamEvent<T> {
    case stream(T)
    case failure(Error)
    case finished
}

public struct SSEEvent {
    let id: String?
    let event: String?
    let data: String
}

public extension PRRequestHandlerManager {
    
    func PRMakeStream<Input: Encodable>(
        from url: String,
        method: HTTPMethod = .post,
        parameters: Input,
        headers: HTTPHeaders? = nil,
        encoder: any ParameterEncoder = URLEncodedFormParameterEncoder.default,
        requestModifier: Session.RequestModifier? = nil
    ) -> AsyncStream<StreamEvent<Data>> {
        AsyncStream { continuation in
            let dataRequest = session.streamRequest(url, method: method, parameters: parameters, encoder: encoder, headers: headers)
            
            dataRequest.responseStream { response in
                switch response.event {
                case .stream(let result):
                    switch result {
                    case .success(let data):
                        continuation.yield(.stream(data))
                    case .failure(let error):
                        continuation.yield(.failure(error))
                        break
                    }
                    
                case .complete(let completion):
                    if let error = completion.error {
                        continuation.yield(.failure(error))
                    } else {
                        continuation.yield(.finished)
                    }
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                dataRequest.cancel()
            }
        }
    }
    
    func PRMakeEventSourceStream<Input: Encodable>(
        from url: String,
        method: HTTPMethod = .post,
        parameters: Input,
        headers: HTTPHeaders? = nil,
        timeout: TimeInterval = 120,
        lastEventID: String? = nil
    ) -> AsyncStream<StreamEvent<PREventSourceMessage>> {
        AsyncStream { continuation in
            let requestUrl = PREnvironmentManager.shared.PRCreateFullRequestUrl(url)
            session.PREventSourceRequest(requestUrl, method: method, parameters: parameters, headers: headers, timeout: timeout, lastEventID: lastEventID).responseEventSource { eventSource in
                switch eventSource.event {
                case .message(let message):
                    print("Event source received message:", message)
                    continuation.yield(.stream(message))
                case .complete(let completion):
                    print("Event source completed:", completion)
                    if let error = completion.error {
                        continuation.yield(.failure(error))
                    } else {
                        continuation.yield(.finished)
                    }
                    continuation.finish()
                }
            }
        }
    }

}

