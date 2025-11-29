//
//  PRRequestHandlerResponseModel.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation
public protocol DefaultInitializable {
    static var defaultValue: Self { get }
}

public typealias DecodableWithDefault = Decodable & DefaultInitializable
public typealias CodableWithDefault = Codable & DefaultInitializable

public struct PRCommonResponse<T: DecodableWithDefault>: Decodable {
    public let errNo: Int
    public let errMsg: String
    public let data: T
    
    private enum CodingKeys: String, CodingKey {
        case errNo
        case errMsg
        case data
    }
    
    public init(from decoder: Decoder) {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            errNo = -1
            errMsg = "invalided key"
            data = T.defaultValue
            return
        }
    
        do {
            errNo = try container.decode(Int.self, forKey: .errNo)
        } catch {
            errNo = -2
        }
        
        do {
            errMsg = try container.decode(String.self, forKey: .errMsg)
        } catch {
            errMsg = "invalided key - errMsg"
        }
        
        do {
            data = try container.decode(T.self, forKey: .data)
        } catch {
            data = T.defaultValue
        }
    }
    
    public func succeed() -> Bool {
        return errNo == 0
    }
}
