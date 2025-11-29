//
//  PRDecodableEventSourceMessage.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation

public struct PRDecodableEventSourceMessage<T: Decodable> {
    
    public var event: String?
    public var id: String?
    public var data: T?
    public var retry: String?
    
}
