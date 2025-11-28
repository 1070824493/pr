//
//  TraceSubscribeOrderModel.swift
//

public struct TraceSubscribeOrderModel: Encodable {
    let traceId: String
    let status: Int
    let failReason: String
}
