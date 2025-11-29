//
//  Alamofire+EventSource.swift
//  AlamofireEventSource
//
//  Created by Daniel Clelland on 7/08/20.
//

import Foundation
import Alamofire

extension Session {
    
    public func PREventSourceRequest<Input: Encodable>(
        _ convertible: URLConvertible,
        method: HTTPMethod = .get,
        parameters: Input? = nil,
        headers: HTTPHeaders? = nil,
        encoder: any ParameterEncoder = URLEncodedFormParameterEncoder.default,
        timeout: TimeInterval = 120,
        lastEventID: String? = nil
    ) -> DataStreamRequest {
        return streamRequest(convertible, method: method, parameters: parameters, encoder: encoder, headers: headers) { request in
            request.timeoutInterval = timeout
            request.headers.add(name: "Accept", value: "text/event-stream")
            request.headers.add(name: "Cache-Control", value: "no-cache")
            if let lastEventID = lastEventID {
                request.headers.add(name: "Last-Event-ID", value: lastEventID)
            }
        }
    }
    
}

extension DataStreamRequest {
    
    public struct PREventSource {
        
        public let event: PREventSourceEvent
        
        public let token: CancellationToken

        public func cancel() {
            token.cancel()
        }
        
    }
    
    public enum PREventSourceEvent {
        
        case message(PREventSourceMessage)
        
        case complete(Completion)
        
    }

    @discardableResult public func responseEventSource(using serializer: PREventSourceSerializer = PREventSourceSerializer(), on queue: DispatchQueue = .main, handler: @escaping (PREventSource) -> Void) -> DataStreamRequest {
        return responseStream(using: serializer, on: queue) { stream in
            switch stream.event {
            case .stream(let result):
                for message in try result.get() {
                    handler(PREventSource(event: .message(message), token: stream.token))
                }
            case .complete(let completion):
                handler(PREventSource(event: .complete(completion), token: stream.token))
            }
        }
    }

}

extension DataStreamRequest {
    
    public struct PRDecodableEventSource<T: Decodable> {
        
        public let event: PRDecodableEventSourceEvent<T>
        
        public let token: CancellationToken

        public func cancel() {
            token.cancel()
        }
        
    }
    
    public enum PRDecodableEventSourceEvent<T: Decodable> {
        
        case message(PRDecodableEventSourceMessage<T>)
        
        case complete(Completion)
        
    }

    @discardableResult public func responseDecodableEventSource<T: Decodable>(using serializer: PRDecodableEventSourceSerializer<T> = PRDecodableEventSourceSerializer(), on queue: DispatchQueue = .main, handler: @escaping (PRDecodableEventSource<T>) -> Void) -> DataStreamRequest {
        return responseStream(using: serializer, on: queue) { stream in
            switch stream.event {
            case .stream(let result):
                for message in try result.get() {
                    handler(PRDecodableEventSource(event: .message(message), token: stream.token))
                }
            case .complete(let completion):
                handler(PRDecodableEventSource(event: .complete(completion), token: stream.token))
            }
        }
    }
    
}
