//
//  CreateSubscribeOrderModel.swift
//


public struct CreateSubscribeOrderRequest: Encodable {
    let skuId: Int
    let payChannel: Int
    let paySource: Int
    let traceId: String
    let ext: String
}

public struct CreateSubscribeOrderResponse: DecodableWithDefault {
    public static var defaultValue: CreateSubscribeOrderResponse {
        return CreateSubscribeOrderResponse(appAccountToken: "", productId: "")
    }
    
    let appAccountToken: String
    let productId: String
}
