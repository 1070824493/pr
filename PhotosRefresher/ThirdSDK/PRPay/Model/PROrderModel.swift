//
//  PROrderModel.swift
//  PhotosRefresher
//
//  Created by tom on 2025/11/28.
//

import Foundation

public struct PRNotifySubscriptionOrderRequest: Encodable {
    let receipt: String
    let payload: String
    let transId: String
    let traceId: String
    let orderId: String
    let originalTransId: String
    let ext: String
}

public struct PRNotifySubscriptionOrderResponse: DecodableWithDefault {
    public static var defaultValue: PRNotifySubscriptionOrderResponse {
        return PRNotifySubscriptionOrderResponse(payStatus: 0)
    }
    
    let payStatus: Int
}

public struct PRQuerySubscriptionOrderModel: Encodable {
    let traceId: String
    let status: Int
    let failReason: String
}

public struct PRSubmitSubscriptionOrderRequest: Encodable {
    let skuId: Int
    let payChannel: Int
    let paySource: Int
    let traceId: String
    let ext: String
}

public struct PRSubmitSubscriptionOrderResponse: DecodableWithDefault {
    public static var defaultValue: PRSubmitSubscriptionOrderResponse {
        return PRSubmitSubscriptionOrderResponse(appAccountToken: "", productId: "")
    }
    
    let appAccountToken: String
    let productId: String
}
