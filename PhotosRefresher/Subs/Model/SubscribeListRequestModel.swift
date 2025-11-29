//
//  SubscribeListRequestModel.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation

struct SubscribeListRequestModel: Encodable {
    let source: Int // 来源
    let scene: Int  //订阅页类型
}
