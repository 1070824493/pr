//
//  ReportSubscribeOrderModel.swift
//



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
