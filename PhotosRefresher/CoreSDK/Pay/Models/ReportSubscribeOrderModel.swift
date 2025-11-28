//
//  ReportSubscribeOrderModel.swift
//



public struct ReportSubscribeOrderRequest: Encodable {
    let receipt: String
    let payload: String
    let transId: String
    let traceId: String
    let orderId: String
    let originalTransId: String
    let ext: String
}

public struct ReportSubscribeOrderResponse: DecodableWithDefault {
    public static var defaultValue: ReportSubscribeOrderResponse {
        return ReportSubscribeOrderResponse(payStatus: 0)
    }
    
    let payStatus: Int
}
