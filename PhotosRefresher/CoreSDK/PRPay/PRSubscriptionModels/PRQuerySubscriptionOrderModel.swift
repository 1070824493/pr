//
//  TraceSubscribeOrderModel.swift
//

public struct PRQuerySubscriptionOrderModel: Encodable {
    let traceId: String
    let status: Int
    let failReason: String
}
