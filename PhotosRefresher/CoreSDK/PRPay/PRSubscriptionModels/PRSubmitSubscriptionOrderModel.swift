//
//  CreateSubscribeOrderModel.swift
//


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
