//
//  PRDecodableEventSourceSerializer.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
import Alamofire

public class PRDecodableEventSourceSerializer<T: Decodable>: DataStreamSerializer {
    
    public let decoder: DataDecoder
    
    private let serializer: PREventSourceSerializer
    
    public init(decoder: DataDecoder = JSONDecoder(), delimiter: Data = PREventSourceSerializer.doubleNewlineDelimiter) {
        self.decoder = decoder
        self.serializer = PREventSourceSerializer(delimiter: delimiter)
    }
    
    public func serialize(_ data: Data) throws -> [PRDecodableEventSourceMessage<T>] {
        return try serializer.serialize(data).map { message in
            return try PRDecodableEventSourceMessage(
                event: message.event,
                id: message.id,
                data: message.data?.data(using: .utf8).flatMap { data in
                    return try decoder.decode(T.self, from: data)
                },
                retry: message.retry
            )
        }
    }
    
}
